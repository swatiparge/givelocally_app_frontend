import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../routes/app_router.dart';

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
  String? _selectedDonationId; // Track selected donation
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
      limit: 50,
    );

    // Sort by created_at descending (latest first)
    data.sort((a, b) {
      final aTime = a['created_at'] ?? a['createdAt'] ?? '';
      final bTime = b['created_at'] ?? b['createdAt'] ?? '';
      return bTime.toString().compareTo(aTime.toString());
    });

    if (mounted) {
      setState(() {
        _nearbyDonations = data;
        _markers = data.map((item) {
          final loc = item['location'];
          final donationId =
              item['donationId'] ?? item['id'] ?? UniqueKey().toString();
          final isSelected = donationId == _selectedDonationId;

          return Marker(
            markerId: MarkerId(donationId),
            position: LatLng(loc['_latitude'], loc['_longitude']),
            icon: _getMarkerIcon(item['category'], isSelected: isSelected),
            infoWindow: InfoWindow(title: item['title'] ?? "Donation"),
            onTap: () => _onMarkerTapped(item),
          );
        }).toSet();
      });
    }

    // update cache info
    _lastQueryPosition = widget.initialPosition;
    _lastQueryCategory = _selectedCategory;
    _lastQueryTime = DateTime.now();
  }

  void _onMarkerTapped(dynamic item) {
    final donationId = item['donationId'] ?? item['id'];
    if (donationId != null) {
      setState(() => _selectedDonationId = donationId.toString());

      // Find and scroll to the card
      final index = _nearbyDonations.indexWhere(
        (d) => (d['donationId'] ?? d['id']) == donationId,
      );
      if (index >= 0) {
        // Scroll to the selected card
        // Note: This would need a ScrollController attached to the ListView
      }
    }
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
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
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

  BitmapDescriptor _getMarkerIcon(String? category, {bool isSelected = false}) {
    if (isSelected) {
      // Return a larger/different marker for selected item
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
    switch (category?.toLowerCase()) {
      case 'food':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'blood':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  void _onCardTapped(dynamic item) {
    debugPrint('Card tapped: ${item['title']}');
    final loc = item['location'];
    final donationId = item['donationId'] ?? item['id'];

    if (loc == null) {
      debugPrint('Location is null for item: ${item['title']}');
      return;
    }

    if (_mapController == null) {
      debugPrint('Map controller is null');
      return;
    }

    try {
      final lat = loc['_latitude'];
      final lng = loc['_longitude'];

      if (lat == null || lng == null) {
        debugPrint('Latitude or longitude is null: lat=$lat, lng=$lng');
        return;
      }

      final position = LatLng(lat.toDouble(), lng.toDouble());
      debugPrint('Moving camera to: $position');

      setState(() {
        _selectedDonationId = donationId?.toString();
      });

      // Animate camera to the donation location
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(position, 16));

      // Refresh markers to show selected state
      _loadNearbyData();
    } catch (e) {
      debugPrint('Error in _onCardTapped: $e');
    }
  }

  void _onRequestButtonPressed(dynamic item) {
    debugPrint('Request button pressed for: ${item['title']}');
    if (context.mounted) {
      context.push(AppRouter.donationDetail, extra: item);
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
    final donationId = item['donationId'] ?? item['id'];
    final isSelected = donationId?.toString() == _selectedDonationId;

    // Format distance nicely
    String distanceStr = "Nearby";
    if (item['distance'] != null) {
      final d = item['distance'];
      if (d is num) {
        distanceStr = d < 1
            ? "${(d * 1000).toInt()}m away"
            : "${d.toStringAsFixed(1)}km away";
      } else if (d is String) {
        final distNum = double.tryParse(d) ?? 0;
        distanceStr = distNum < 1
            ? "${(distNum * 1000).toInt()}m away"
            : "${distNum.toStringAsFixed(1)}km away";
      }
    }

    return InkWell(
      onTap: () => _onCardTapped(item),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F8E9) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: const Color(0xFF4CAF50), width: 2)
              : null,
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
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
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
                  Text(
                    "📍 $distanceStr",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      debugPrint('Request button tapped');
                      _onRequestButtonPressed(item);
                    },
                    child: Container(
                      width: double.infinity,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F8E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          "REQUEST",
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
