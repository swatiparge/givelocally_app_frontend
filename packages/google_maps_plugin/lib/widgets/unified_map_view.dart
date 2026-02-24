import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import '../models/map_marker_item.dart';
import '../services/geolocation_service.dart';
import 'dart:math';

/// Main map widget for displaying generic items with auto-location and smart refresh.
class UnifiedMapView extends StatefulWidget {
  /// Callback to fetch items based on camera center and radius (in km).
  final Future<List<MapMarkerItem>> Function(LatLng center, double radius)
      onFetchItems;

  /// Map of category names to loaded BitmapDescriptors.
  final Map<String, BitmapDescriptor> categoryIcons;

  /// Callback when a marker is tapped.
  final void Function(MapMarkerItem item) onItemTap;

  /// Optional custom map style (JSON string).
  final String? mapStyle;

  /// Initial camera position. If null, will try to use current location.
  final LatLng? initialPosition;

  const UnifiedMapView({
    super.key,
    required this.onFetchItems,
    required this.categoryIcons,
    required this.onItemTap,
    this.mapStyle,
    this.initialPosition,
  });

  @override
  State<UnifiedMapView> createState() => _UnifiedMapViewState();
}

class _UnifiedMapViewState extends State<UnifiedMapView> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _currentCenter;
  LatLng? _lastFetchCenter;
  Timer? _debounceTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialPosition;
    _initializeLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
        _fetchItems(_currentCenter!);
      }
    } else {
      _fetchItems(_currentCenter!);
    }
  }

  void _moveCameraTo(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 14),
      ),
    );
  }

  void _onCameraMove(CameraPosition position) {
    setState(() => _currentCenter = position.target);

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_lastFetchCenter == null ||
          _calculateDistance(_lastFetchCenter!, position.target) > 0.5) {
        _fetchItems(position.target);
      }
    });
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    // Simple distance calculation in km
    const double earthRadius = 6371;
    final double dLat = (p2.latitude - p1.latitude) * (3.14159265359 / 180);
    final double dLng = (p2.longitude - p1.longitude) * (3.14159265359 / 180);
    final double a = (dLat / 2) * (dLat / 2) +
        (dLng / 2) *
            (dLng / 2) *
            (1 + (3.14159265359 / 180) * (1 + (3.14159265359 / 180)));
    final double c = 2 * (dLat / 2).abs() + (dLng / 2).abs();
    return earthRadius * c;
  }

  Future<void> _fetchItems(LatLng center) async {
    setState(() => _isLoading = true);
    try {
      // Approximate radius based on zoom level or fixed 5km
      final items = await widget.onFetchItems(center, 5.0);
      _updateMarkers(items);
      setState(() => _lastFetchCenter = center);
    } catch (e) {
      debugPrint('Error fetching items: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateMarkers(List<MapMarkerItem> items) {
    final markers = items.map((item) {
      final icon =
          widget.categoryIcons[item.category] ?? BitmapDescriptor.defaultMarker;

      return Marker(
        markerId: MarkerId(item.id),
        position: LatLng(item.latitude, item.longitude),
        icon: icon,
        infoWindow: InfoWindow(
          title: item.title,
          snippet: item.snippet,
          onTap: () => widget.onItemTap(item),
        ),
        onTap: () => widget.onItemTap(item),
      );
    }).toSet();

    setState(() => _markers = markers);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentCenter == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) => _mapController = controller,
          initialCameraPosition: CameraPosition(
            target: _currentCenter!,
            zoom: 14,
          ),
          markers: _markers,
          onCameraIdle: () => _onCameraMove,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapType: MapType.normal,
          style: widget.mapStyle,
        ),
        if (_isLoading)
          const Positioned(
            top: 60,
            right: 20,
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}
