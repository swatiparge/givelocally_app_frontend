import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/default_location.dart';
import '../../services/geolocation_service.dart';

class LocationPickerField extends StatefulWidget {
  final LatLng? selectedLocation;
  final String address;
  final Function(LatLng location, String address) onLocationSelected;

  const LocationPickerField({
    super.key,
    required this.selectedLocation,
    required this.address,
    required this.onLocationSelected,
  });

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  GoogleMapController? _previewController;

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LocationPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldLoc = oldWidget.selectedLocation;
    final newLoc = widget.selectedLocation;
    if (oldLoc == null || newLoc == null) return;

    final moved =
        oldLoc.latitude != newLoc.latitude ||
        oldLoc.longitude != newLoc.longitude;
    if (moved) {
      _previewController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: newLoc, zoom: 15),
        ),
      );
    }
  }

  Future<void> _openFullPicker(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FullMapPickerScreen(initialLocation: widget.selectedLocation),
      ),
    );

    if (!context.mounted) return;
    if (result != null && result is Map<String, dynamic>) {
      widget.onLocationSelected(result['location'], result['address']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLocation = widget.selectedLocation;

    return InkWell(
      onTap: () => _openFullPicker(context),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              if (selectedLocation != null)
                IgnorePointer(
                  child: GoogleMap(
                    onMapCreated: (c) {
                      _previewController = c;
                      c.moveCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(target: selectedLocation, zoom: 15),
                        ),
                      );
                    },
                    initialCameraPosition: CameraPosition(
                      target: selectedLocation,
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId("selected"),
                        position: selectedLocation,
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.green.shade600,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Tap to select location on Map",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              // Overlay to ensure the whole container is clickable
              Container(color: Colors.transparent),
            ],
          ),
        ),
      ),
    );
  }
}

// WF-14: Full Screen Map Picker
class FullMapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const FullMapPickerScreen({super.key, this.initialLocation});

  @override
  State<FullMapPickerScreen> createState() => _FullMapPickerScreenState();
}

class _FullMapPickerScreenState extends State<FullMapPickerScreen> {
  GoogleMapController? _controller;
  late LatLng _currentCenter;
  Timer? _idleDebounce;
  bool _isResolvingAddress = false;
  String? _address;

  @override
  void initState() {
    super.initState();
    _currentCenter =
        widget.initialLocation ?? const LatLng(kDefaultLat, kDefaultLng);

    // If no initial location is provided, attempt to use device location.
    if (widget.initialLocation == null) {
      _useCurrentLocation();
    } else {
      _resolveAddress();
    }
  }

  @override
  void dispose() {
    _idleDebounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final pos = await GeolocationService.getCurrentPosition();
    if (pos == null || !mounted) return;
    final loc = LatLng(pos.latitude, pos.longitude);
    setState(() => _currentCenter = loc);
    await _controller?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: loc, zoom: 16)),
    );
    await _resolveAddress();
  }

  void _onCameraIdle() {
    _idleDebounce?.cancel();
    _idleDebounce = Timer(const Duration(milliseconds: 450), _resolveAddress);
  }

  Future<void> _resolveAddress() async {
    if (!mounted) return;
    setState(() => _isResolvingAddress = true);

    try {
      final placemarks = await placemarkFromCoordinates(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );
      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.name ?? '').trim().isNotEmpty) p.name!.trim(),
          if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
          if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
          if ((p.administrativeArea ?? '').trim().isNotEmpty)
            p.administrativeArea!.trim(),
        ];
        _address = parts.join(', ');
      }
    } catch (_) {
      // ignore; keep address null
    } finally {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Select Pickup Point",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 16,
            ),
            onMapCreated: (c) => _controller = c,
            onCameraMove: (pos) => _currentCenter = pos.target,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 35),
              child: Icon(Icons.location_on, color: Colors.red, size: 45),
            ),
          ),
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isResolvingAddress)
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Getting address...'),
                        ],
                      )
                    else
                      Text(
                        _address ?? 'Move the map to set pickup point',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Lat: ${_currentCenter.latitude.toStringAsFixed(4)}, '
                      'Lng: ${_currentCenter.longitude.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: FloatingActionButton.small(
                    heroTag: 'useCurrentLocation',
                    onPressed: _useCurrentLocation,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, {
                      'location': _currentCenter,
                      'address': _address ?? 'Selected Location',
                    });
                  },
                  child: const Text(
                    "Confirm Location",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
