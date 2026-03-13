import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../services/geolocation_service.dart';

/// Result returned by the LocationPicker
class LocationResult {
  final LatLng location;
  final String? address;
  final String? area;

  const LocationResult({
    required this.location,
    this.address,
    this.area,
  });
}

/// Configuration for LocationPicker appearance and behavior
class LocationPickerConfig {
  final String title;
  final String confirmButtonText;
  final bool showBackButton;
  final bool showManualSearch;
  final bool showPrivacyNotice;
  final bool showDetectedBadge;
  final String? privacyNoticeText;
  final double initialZoom;

  const LocationPickerConfig({
    this.title = 'Confirm Location',
    this.confirmButtonText = 'Confirm Location',
    this.showBackButton = true,
    this.showManualSearch = true,
    this.showPrivacyNotice = true,
    this.showDetectedBadge = true,
    this.privacyNoticeText,
    this.initialZoom = 15,
  });

  /// Config for onboarding flow
  static const LocationPickerConfig onboarding = LocationPickerConfig(
    title: 'Confirm Location',
    confirmButtonText: 'Confirm Location',
    showBackButton: true,
    showManualSearch: true,
    showPrivacyNotice: true,
    showDetectedBadge: true,
    initialZoom: 15,
  );

  /// Config for donation pickup location
  static const LocationPickerConfig donationPickup = LocationPickerConfig(
    title: 'Select Pickup Point',
    confirmButtonText: 'Confirm Location',
    showBackButton: true,
    showManualSearch: false,
    showPrivacyNotice: false,
    showDetectedBadge: false,
    initialZoom: 16,
  );
}

/// Widget for picking a location on the map.
/// Features a draggable pin that stays fixed while the map moves.
class LocationPicker extends StatefulWidget {
  /// Callback when user confirms the location.
  final ValueChanged<LocationResult> onLocationSelected;

  /// Initial camera position. If null, will try to use current location.
  final LatLng? initialPosition;

  /// Configuration for appearance and behavior.
  final LocationPickerConfig config;

  const LocationPicker({
    super.key,
    required this.onLocationSelected,
    this.initialPosition,
    this.config = LocationPickerConfig.onboarding,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _currentCenter;
  String? _address;
  String? _area;
  bool _isLoadingAddress = false;
  bool _isDetected = false;
  bool _showSearchField = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialPosition;
    _initializeLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    if (_currentCenter == null) {
      final position = await GeolocationService.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _currentCenter = LatLng(position.latitude, position.longitude);
          _isDetected = true;
        });
        _moveCameraTo(_currentCenter!);
        _fetchAddress();
      }
    } else {
      _fetchAddress();
    }
  }

  void _moveCameraTo(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: widget.config.initialZoom),
      ),
    );
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _currentCenter = position.target;
      _isDetected = false;
    });
  }

  Future<void> _fetchAddress() async {
    if (_currentCenter == null || !mounted) return;

    setState(() => _isLoadingAddress = true);

    try {
      final placemarks = await placemarkFromCoordinates(
        _currentCenter!.latitude,
        _currentCenter!.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final area = place.subLocality?.isNotEmpty == true
            ? place.subLocality!
            : (place.locality ?? "Unknown Area");
        final fullAddress =
            "${place.name}, ${place.locality}, ${place.postalCode}";

        setState(() {
          _area = area;
          _address = fullAddress;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
      if (mounted) {
        setState(() {
          _address = null;
          _area = "Custom Location";
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _confirmLocation() {
    if (_currentCenter != null) {
      widget.onLocationSelected(
        LocationResult(
          location: _currentCenter!,
          address: _address,
          area: _area,
        ),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    final position = await GeolocationService.getCurrentPosition();
    if (position != null && mounted) {
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentCenter = location;
        _isDetected = true;
      });
      _moveCameraTo(location);
      await _fetchAddress();
    }
  }

  Future<void> _onSearchSubmitted(String value) async {
    if (value.trim().isEmpty) return;

    setState(() => _isLoadingAddress = true);
    _searchFocusNode.unfocus();

    try {
      final locations = await locationFromAddress(value);
      if (locations.isNotEmpty && mounted) {
        final loc = locations.first;
        final newPos = LatLng(loc.latitude, loc.longitude);

        setState(() {
          _currentCenter = newPos;
          _isDetected = false;
        });

        _moveCameraTo(newPos);
        await _fetchAddress();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Location not found. Try a more specific address.')),
        );
        setState(() => _isLoadingAddress = false);
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Could not find location. Try City, State or Pincode.')),
        );
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentCenter == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildCenterPin(),
          _buildTopBar(),
          _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: CameraPosition(
        target: _currentCenter!,
        zoom: widget.config.initialZoom,
      ),
      onCameraMove: _onCameraMove,
      onCameraIdle: () {
        _debounceTimer?.cancel();
        _debounceTimer =
            Timer(const Duration(milliseconds: 450), _fetchAddress);
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      mapType: MapType.normal,
    );
  }

  Widget _buildCenterPin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isLoadingAddress ? "Locating..." : "Move map to adjust",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const Icon(Icons.location_on, color: Colors.red, size: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (widget.config.showBackButton)
              _circleBtn(Icons.arrow_back, () => Navigator.pop(context)),
            Expanded(
              child: Center(
                child: Text(
                  widget.config.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildAddressHeader(),
            const SizedBox(height: 4),
            Text(
              _address ?? 'Move the map to set location',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            if (widget.config.showPrivacyNotice) ...[
              const SizedBox(height: 20),
              _buildPrivacyNotice(),
            ],
            if (widget.config.showManualSearch) ...[
              const SizedBox(height: 16),
              _buildManualSearchToggle(),
              if (_showSearchField) ...[
                const SizedBox(height: 12),
                _buildSearchBar(),
              ],
            ],
            const SizedBox(height: 16),
            _buildUseCurrentLocationButton(),
            const SizedBox(height: 12),
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _area ?? 'Unknown Area',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.config.showDetectedBadge && _isDetected) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              "DETECTED",
              style: TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.config.privacyNoticeText ??
                  "Privacy & Trust: Your exact location is private. We only show an approximate zone.",
              style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSearchToggle() {
    return Center(
      child: TextButton(
        onPressed: () {
          setState(() {
            _showSearchField = !_showSearchField;
          });
          if (_showSearchField) {
            _searchFocusNode.requestFocus();
          }
        },
        child: Text(
          _showSearchField
              ? "Hide manual search"
              : "Enter address manually instead",
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                hintText: "Search area, city or pincode",
                border: InputBorder.none,
              ),
              onSubmitted: _onSearchSubmitted,
            ),
          ),
          if (_isLoadingAddress)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () => setState(() => _searchController.clear()),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF66BB6A),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: 0,
      ),
      onPressed: _isLoadingAddress ? null : _confirmLocation,
      child: _isLoadingAddress
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
              widget.config.confirmButtonText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );
  }

  Widget _buildUseCurrentLocationButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: FloatingActionButton.small(
        heroTag: 'useCurrentLocation',
        onPressed: _useCurrentLocation,
        backgroundColor: Colors.grey.shade100,
        child: const Icon(Icons.my_location, color: Colors.black87, size: 20),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return CircleAvatar(
      backgroundColor: Colors.white,
      child: IconButton(
        icon: Icon(icon, color: Colors.black),
        onPressed: onTap,
      ),
    );
  }
}
