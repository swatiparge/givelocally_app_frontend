import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/geolocation_service.dart';

/// Result returned by the LocationPicker
class LocationResult {
  final LatLng location;
  final String? address;

  const LocationResult({required this.location, this.address});
}

/// Widget for picking a location on the map.
/// Features a draggable pin that stays fixed while the map moves.
class LocationPicker extends StatefulWidget {
  /// Callback when user confirms the location.
  final ValueChanged<LocationResult> onLocationSelected;

  /// Initial camera position. If null, will try to use current location.
  final LatLng? initialPosition;

  /// Text to display on the confirm button.
  final String confirmButtonText;

  const LocationPicker({
    super.key,
    required this.onLocationSelected,
    this.initialPosition,
    this.confirmButtonText = 'Confirm Location',
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _currentCenter;
  String? _address;
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialPosition;
    _initializeLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    if (_currentCenter == null) {
      final position = await GeolocationService.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _currentCenter = LatLng(position.latitude, position.longitude);
        });
        _moveCameraTo(_currentCenter!);
      }
    }
  }

  void _moveCameraTo(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 16),
      ),
    );
  }

  void _onCameraMove(CameraPosition position) {
    setState(() => _currentCenter = position.target);
  }

  Future<void> _fetchAddress() async {
    // This would typically call the geocodeAddress Cloud Function
    // For now, we'll just show loading state
    setState(() => _isLoadingAddress = true);

    // TODO: Call your geocodeAddress cloud function here
    // Example:
    // final result = await FirebaseFunctions.instance
    //   .httpsCallable('geocodeAddress')
    //   .call({'lat': _currentCenter!.latitude, 'lng': _currentCenter!.longitude});
    //
    // setState(() => _address = result.data['formatted_address']);

    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    setState(() => _isLoadingAddress = false);
  }

  void _confirmLocation() {
    if (_currentCenter != null) {
      widget.onLocationSelected(
        LocationResult(location: _currentCenter!, address: _address),
      );
    }
  }

  void _useCurrentLocation() async {
    final position = await GeolocationService.getCurrentPosition();
    if (position != null && mounted) {
      final location = LatLng(position.latitude, position.longitude);
      _moveCameraTo(location);
      setState(() => _currentCenter = location);
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
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: _currentCenter!,
              zoom: 16,
            ),
            onCameraIdle: () => _fetchAddress(),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
          ),
          // Center pin that stays fixed
          const Center(
            child: Icon(
              Icons.location_pin,
              size: 50,
              color: Colors.red,
            ),
          ),
          // Top bar with address preview
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingAddress)
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
                        _address ?? 'Address will appear here',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${_currentCenter!.latitude.toStringAsFixed(4)}, '
                      'Lng: ${_currentCenter!.longitude.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom bar with action buttons
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton.small(
                  onPressed: _useCurrentLocation,
                  heroTag: 'useCurrentLocation',
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirmLocation,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(widget.confirmButtonText),
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
