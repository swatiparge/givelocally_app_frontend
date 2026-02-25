import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/api_service.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key, required this.initialPosition});

  final LatLng initialPosition;

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  GoogleMapController? _mapController;
  final ApiService _apiService = ApiService();

  Set<Marker> _markers = {};
  List<dynamic> _nearbyDonations = [];
  String _selectedCategory = "All";

  // ------------------------------------------------------------------
  // rate limiting / caching helpers so we don't spam the backend
  LatLng? _lastQueryPosition;
  String? _lastQueryCategory;
  DateTime? _lastQueryTime;
  Timer? _debounceTimer;
  
  static const double _kMinMoveMeters = 500; // only reload if moved >500m
  static const Duration _kMinReloadInterval = Duration(seconds: 30);
  // ------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _scheduleLoad(force: true);
  }

  @override
  void didUpdateWidget(covariant MapViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPos = oldWidget.initialPosition;
    final newPos = widget.initialPosition;
    final movedMeters = _haversineDistance(
      oldPos.latitude,
      oldPos.longitude,
      newPos.latitude,
      newPos.longitude,
    );

    if (movedMeters > _kMinMoveMeters) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: newPos, zoom: 14),
        ),
      );
      _scheduleLoad();
    }
  }

  /// Actually performs the network call.
  Future<void> _loadNearbyData() async {
    final String? categoryParam = _selectedCategory == "All"
        ? null
        : _selectedCategory.toLowerCase();

    final data = await _apiService.fetchNearbyDonations(
      lat: widget.initialPosition.latitude,
      lng: widget.initialPosition.longitude,
      category: categoryParam,
      radiusKm: 20,
    );

    if (mounted) {
      setState(() {
        _nearbyDonations = data;
        _markers = data.map((item) {
          final loc = item['location'];
          return Marker(
            markerId: MarkerId(
              item['donationId'] ?? item['title'] ?? UniqueKey().toString(),
            ),
            position: LatLng(loc['_latitude'], loc['_longitude']),
            icon: _getMarkerIcon(item['category']),
            infoWindow: InfoWindow(title: item['title'] ?? "Donation"),
          );
        }).toSet();
      });
    }

    // update cache info
    _lastQueryPosition = widget.initialPosition;
    _lastQueryCategory = _selectedCategory;
    _lastQueryTime = DateTime.now();
  }

  /// Schedule a load with debounce and rate limit checks.
  void _scheduleLoad({bool force = false}) {
    // cancel any pending timer
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (force || _shouldLoad()) {
        _loadNearbyData();
      }
    });
  }

  /// Determines whether a new network request should be made based on
  /// movement distance, category change, or time since the last request.
  bool _shouldLoad() {
    // 1. If category changed, we MUST load
    if (_selectedCategory != _lastQueryCategory) return true;

    final now = DateTime.now();
    
    // 2. If it's been a while, we should load
    if (_lastQueryTime == null || 
        now.difference(_lastQueryTime!) > _kMinReloadInterval) {
      return true;
    }

    // 3. Check distance threshold
    if (_lastQueryPosition != null) {
      final dist = _haversineDistance(
        _lastQueryPosition!.latitude,
        _lastQueryPosition!.longitude,
        widget.initialPosition.latitude,
        widget.initialPosition.longitude,
      );
      if (dist > _kMinMoveMeters) {
        return true;
      }
    }

    return false;
  }

  /// Haversine distance between two lat/lng pairs in meters.
  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // earth radius in metres
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
            cos(_deg2rad(lat1)) *
                cos(_deg2rad(lat2)) *
                (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  BitmapDescriptor _getMarkerIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'food':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'blood':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Google Map Layer
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Custom UI Overlay (Category Row)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: _buildCategoryRow(),
            ),
          ),

          // 3. Bottom Carousel (Fixed Height & Error Handling)
          Positioned(
            bottom: 40, // Adjusted to sit above the bottom nav bar
            left: 0,
            right: 0,
            child: _nearbyDonations.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 140, // Reduced height to prevent overflow
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _nearbyDonations.length,
                      itemBuilder: (context, index) =>
                          _buildBottomListCard(_nearbyDonations[index]),
                    ),
                  ),
          ),

          // 4. Recenter FAB
          Positioned(
            right: 16,
            bottom: 260, // Lifted up so it doesn't overlap the carousel
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () => _mapController?.animateCamera(
                CameraUpdate.newLatLng(widget.initialPosition),
              ),
              child: const Icon(Icons.my_location, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    final cats = ["All", "Blood", "Food", "Appliances", "Stationery"];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        itemBuilder: (context, i) {
          bool sel = _selectedCategory == cats[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cats[i]),
              selected: sel,
              onSelected: (v) {
                if (v) {
                  setState(() => _selectedCategory = cats[i]);
                  _scheduleLoad(force: true);
                }
              },
              selectedColor: Colors.green,
              labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87),
              backgroundColor: Colors.white,
              shape: StadiumBorder(
                side: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomListCard(dynamic item) {
    // Determine the image URL or use a local backup asset to avoid 403 errors
    final List images = item['images'] as List? ?? [];
    final String imageUrl = images.isNotEmpty ? images[0] : "";

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Fixed size image container with error handling
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 90,
              height: 90,
              color: Colors.grey.shade100,
              child: imageUrl.isEmpty
                  ? const Icon(Icons.image_outlined, color: Colors.grey)
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['category'].toString().toUpperCase(),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  item['title'] ?? "No Title",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  "📍 0.5 km away",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F8E9),
                      foregroundColor: Colors.green,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "REQUEST",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
