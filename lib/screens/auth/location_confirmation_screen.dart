import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/geolocation_service.dart';
import '../../services/auth_service.dart';
import '../../config/default_location.dart';
import 'profile_setup_screen.dart';

class LocationConfirmationScreen extends StatefulWidget {
  const LocationConfirmationScreen({super.key});

  @override
  State<LocationConfirmationScreen> createState() => _LocationConfirmationScreenState();
}

class _LocationConfirmationScreenState extends State<LocationConfirmationScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPos = const LatLng(kDefaultLat, kDefaultLng);
  String _addressTitle = "Detecting...";
  String _fullAddress = "Searching for your location...";
  bool _isDetected = false;
  bool _showManualSearch = false;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isReverseGeocoding = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    final pos = await GeolocationService.getCurrentPosition();
    if (pos != null) {
      final newLatLng = LatLng(pos.latitude, pos.longitude);
      _updateLocation(newLatLng, isDetected: true);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLatLng, 16));
    } else {
      _updateLocation(_currentPos, isDetected: false);
    }
  }

  Future<void> _updateLocation(LatLng latLng, {bool isDetected = false}) async {
    if (!mounted) return;
    
    setState(() {
      _currentPos = latLng;
      _isDetected = isDetected;
      _isReverseGeocoding = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks.first;
        setState(() {
          _addressTitle = place.subLocality?.isNotEmpty == true 
              ? place.subLocality! 
              : (place.locality ?? "Unknown Area");
          _fullAddress = "${place.name}, ${place.locality}, ${place.postalCode}";
          _isReverseGeocoding = false;
        });
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
      if (mounted) {
        setState(() {
          _isReverseGeocoding = false;
          if (!isDetected) {
            _addressTitle = "Custom Location";
            _fullAddress = "Address not found, but you can still confirm.";
          }
        });
      }
    }
  }

  Future<void> _onSearchSubmitted(String value) async {
    if (value.trim().isEmpty) return;
    
    setState(() => _isSearching = true);
    _searchFocusNode.unfocus();

    try {
      List<Location> locations = await locationFromAddress(value);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newPos = LatLng(loc.latitude, loc.longitude);
        
        // IMPORTANT: Update the local state first
        setState(() {
          _currentPos = newPos;
          _isDetected = false;
        });

        // Then move the map
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newPos, 16)
        );
        
        // Geocoding will be triggered by onCameraIdle
      } else {
        _showError("Location not found. Please try a more specific address.");
      }
    } catch (e) {
      debugPrint("Search error: $e");
      _showError("Could not find location. Try entering City, State or Pincode.");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmLocation() async {
    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final uid = authService.firebaseUser?.uid;

      if (uid == null) throw Exception("User not authenticated");

      // Save location to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'location': GeoPoint(_currentPos.latitude, _currentPos.longitude),
        'address': _fullAddress,
        'area': _addressTitle,
        'location_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (c) => const ProfileSetupScreen())
        );
      }
    } catch (e) {
      debugPrint("Error saving location: $e");
      if (mounted) {
        _showError("Failed to save location: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Map Layer
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPos, zoom: 15),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (pos) {
              _currentPos = pos.target;
              // Only update text to "Updating..." if we're not in the middle of a manual search result move
              if (!_isSearching && !_isReverseGeocoding) {
                setState(() {
                  _addressTitle = "Updating...";
                  _fullAddress = "Fetching address details...";
                });
              }
            },
            onCameraIdle: () {
              // Trigger address fetch when map stops moving
              _updateLocation(_currentPos, isDetected: false);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Top UI (Back and Search)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _circleBtn(Icons.arrow_back, () => Navigator.pop(context)),
                      const Expanded(
                        child: Center(
                          child: Text("Confirm Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 40), 
                    ],
                  ),
                  if (_showManualSearch) ...[
                    const SizedBox(height: 20),
                    _buildSearchBar(),
                  ],
                ],
              ),
            ),
          ),

          // 3. Center Pin Overlay (Red Pin)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      _isReverseGeocoding || _isSearching ? "Locating..." : "Move map to adjust", 
                      style: const TextStyle(color: Colors.white, fontSize: 12)
                    ),
                  ),
                  const Icon(Icons.location_on, color: Colors.red, size: 50),
                ],
              ),
            ),
          ),

          // 4. Bottom Detail Sheet
          _buildBottomDetailCard(),
        ],
      ),
    );
  }

  Widget _buildBottomDetailCard() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(_addressTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
                ),
                if (_isDetected) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                    child: const Text("DETECTED", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(_fullAddress, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 20),
            _buildPrivacyNotice(),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF66BB6A),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : _confirmLocation,
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Confirm Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _showManualSearch = !_showManualSearch;
                  });
                  if (_showManualSearch) {
                    _searchFocusNode.requestFocus();
                  }
                },
                child: Text(
                  _showManualSearch ? "Hide manual search" : "Enter address manually instead",
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyNotice() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(16)),
    child: Row(children: [
      const Icon(Icons.verified_user, color: Colors.blue, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text("Privacy & Trust: Your exact location is private. We only show an approximate zone.", style: TextStyle(fontSize: 11, color: Colors.blue.shade800))),
    ]),
  );

  Widget _buildSearchBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white, 
      borderRadius: BorderRadius.circular(16), 
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]
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
        if (_isSearching)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        else if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, size: 20),
            onPressed: () => setState(() => _searchController.clear()),
          ),
      ],
    ),
  );

  Widget _circleBtn(IconData icon, VoidCallback tap) => CircleAvatar(
    backgroundColor: Colors.white, 
    child: IconButton(icon: Icon(icon, color: Colors.black), onPressed: tap)
  );
}
