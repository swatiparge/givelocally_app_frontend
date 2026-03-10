import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/ListView/urgent_blood_request_card.dart';
import '../../routes/app_router.dart';

class ViewAllDonationsScreen extends ConsumerStatefulWidget {
  final String title;
  final String category;
  final List<String>? categories;
  final double lat;
  final double lng;

  const ViewAllDonationsScreen({
    super.key,
    required this.title,
    required this.category,
    this.categories,
    required this.lat,
    required this.lng,
  });

  @override
  ConsumerState<ViewAllDonationsScreen> createState() => _ViewAllDonationsScreenState();
}

class _ViewAllDonationsScreenState extends ConsumerState<ViewAllDonationsScreen> {
  late Future<List<dynamic>> _fetchFuture;
  final ApiService _apiService = ApiService();
  double _currentRadius = 50.0; // Default to 50km to see everything initially

  @override
  void initState() {
    super.initState();
    _initFetch();
  }

  void _initFetch() {
    final String? categoryOrNull = widget.category.trim().isEmpty
        ? null
        : widget.category.trim();

    _fetchFuture = widget.categories != null
        ? _apiService.fetchMultipleCategories(
            lat: widget.lat,
            lng: widget.lng,
            categories: widget.categories!,
            radiusKm: _currentRadius,
            limit: 50,
          )
        : _apiService.fetchNearbyDonations(
            lat: widget.lat,
            lng: widget.lng,
            category: categoryOrNull,
            radiusKm: _currentRadius,
            limit: 50,
          );
  }

  List<dynamic> _applySorting(List<dynamic> items) {
    List<dynamic> sortedItems = List.from(items);
    // STICKY SORT: Always sort by latest first
    sortedItems.sort((a, b) {
      final dateA = _extractDateTime(a);
      final dateB = _extractDateTime(b);
      return dateB.compareTo(dateA); // Newest first
    });
    return sortedItems;
  }

  DateTime _extractDateTime(dynamic item) {
    // Aggressive date extraction from multiple possible fields
    final dateData = item['createdAt'] ?? 
                     item['created_at'] ?? 
                     item['timestamp'] ?? 
                     (item['pickup_window'] != null ? item['pickup_window']['start_date'] : null) ??
                     item['expiry_date']; // Fallback to expiry if creation is missing
    
    if (dateData == null) return DateTime(2000);

    if (dateData is Map) {
      final seconds = dateData['_seconds'] ?? dateData['seconds'] ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    if (dateData is int) {
      // Handle both seconds and milliseconds
      if (dateData < 10000000000) return DateTime.fromMillisecondsSinceEpoch(dateData * 1000);
      return DateTime.fromMillisecondsSinceEpoch(dateData);
    }
    if (dateData is String) return DateTime.tryParse(dateData) ?? DateTime(2000);
    
    return DateTime(2000);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(userIdProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _initFetch();
          });
          await _fetchFuture;
        },
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _fetchFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final rawItems = snapshot.data ?? [];
                  final items = _applySorting(rawItems);

                  if (items.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        const Center(child: Text("No items found in this range.")),
                        const Center(child: Text("Try increasing the distance filter.", style: TextStyle(color: Colors.grey, fontSize: 12))),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isPostedByMe = currentUserId != null && 
                          (item['donorId'] == currentUserId || item['userId'] == currentUserId);

                      if (widget.category == "blood" || item['category'] == "blood") {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => context.goToDonationDetail(item as Map<String, dynamic>),
                            borderRadius: BorderRadius.circular(16),
                            child: UrgentBloodRequestCard(donation: item),
                          ),
                        );
                      }
                      return _buildVerticalListCard(context, item, isPostedByMe);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 2))
        ]
      ),
      child: Row(
        children: [
          Icon(Icons.tune, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 8),
          const Text("Distance Filter:", style: TextStyle(fontSize: 14, color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          _distanceDropdown(),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _distanceDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: _currentRadius,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.green.shade700),
          style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 13),
          items: [1.0, 3.0, 5.0, 10.0, 50.0].map((radius) {
            return DropdownMenuItem(
              value: radius,
              child: Text("${radius.toInt()} km"),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _currentRadius = val;
                _initFetch();
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildVerticalListCard(BuildContext context, dynamic item, bool isPostedByMe) {
    final images = item['images'] as List? ?? [];
    final String imageUrl = images.isNotEmpty ? images[0] : "";
    
    final String donorName = item['donor_name'] ?? item['donorName'] ?? item['userName'] ?? item['username'] ?? item['name'] ?? "Donor";
    final String userImage = item['userImage'] ?? item['donorImage'] ?? item['profilePicture'] ?? "";
    final String userRating = (item['userRating'] ?? item['donorRating'] ?? item['averageRating'] ?? "4.5").toString();
    
    // Format distance nicely
    String distanceStr = "Nearby";
    if (item['distance'] != null) {
      final d = item['distance'];
      distanceStr = d < 1 ? "${(d * 1000).toInt()}m away" : "${d.toStringAsFixed(1)}km away";
    }

    return InkWell(
      onTap: () => context.goToDonationDetail(item as Map<String, dynamic>),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      height: 200,
                      color: const Color(0xFFF1F8E9),
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
                    ),
                    child: const Text(
                      "Free",
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (isPostedByMe)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "My Post",
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['title'] ?? "Item",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212121),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        distanceStr,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${item['category'] ?? 'General'}",
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: userImage.isNotEmpty ? NetworkImage(userImage) : null,
                        child: userImage.isEmpty 
                            ? const Icon(Icons.person, size: 20, color: Colors.grey) 
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPostedByMe ? "You" : donorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF212121),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  userRating,
                                  style: const TextStyle(
                                    color: Color(0xFF757575),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isPostedByMe)
                        ElevatedButton(
                          onPressed: () => context.goToDonationDetail(item as Map<String, dynamic>),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F8E9),
                            foregroundColor: const Color(0xFF4CAF50),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            "Request",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
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
