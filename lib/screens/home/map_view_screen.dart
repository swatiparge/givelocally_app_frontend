import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadNearbyData();
  }

  @override
  void didUpdateWidget(covariant MapViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPos = oldWidget.initialPosition;
    final newPos = widget.initialPosition;
    final moved =
        oldPos.latitude != newPos.latitude ||
        oldPos.longitude != newPos.longitude;
    if (moved) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: newPos, zoom: 14),
        ),
      );
      _loadNearbyData();
    }
  }

  Future<void> _loadNearbyData() async {
    final data = await _apiService.fetchNearbyDonations(
      lat: widget.initialPosition.latitude,
      lng: widget.initialPosition.longitude,
      category: _selectedCategory == "All"
          ? null
          : _selectedCategory.toLowerCase(),
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
  }

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
                setState(() => _selectedCategory = cats[i]);
                _loadNearbyData();
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
