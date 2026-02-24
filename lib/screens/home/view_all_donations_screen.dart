import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/ListView/urgent_blood_request_card.dart';

class ViewAllDonationsScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final ApiService apiService = ApiService();
    final String? categoryOrNull = category.trim().isEmpty
        ? null
        : category.trim();
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.firebaseUser?.uid;

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
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: categories != null
                  ? apiService.fetchMultipleCategories(
                      lat: lat,
                      lng: lng,
                      categories: categories!,
                    )
                  : apiService.fetchNearbyDonations(
                      lat: lat,
                      lng: lng,
                      category: categoryOrNull,
                      radiusKm: 50,
                    ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return const Center(child: Text("No items found."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isPostedByMe = currentUserId != null && 
                        (item['donorId'] == currentUserId || item['userId'] == currentUserId);

                    // Blood category uses its specific wide card
                    if (category == "blood" || item['category'] == "blood") {
                      return InkWell(
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/donation-detail',
                          arguments: item,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: UrgentBloodRequestCard(donation: item),
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
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _filterChip("Sort by"),
          const SizedBox(width: 8),
          _filterChip("Distance"),
          const Spacer(),
          const Icon(Icons.tune, color: Colors.black54),
        ],
      ),
    );
  }

  Widget _filterChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(children: [Text(label), const Icon(Icons.arrow_drop_down)]),
  );

  Widget _buildVerticalListCard(BuildContext context, dynamic item, bool isPostedByMe) {
    final images = item['images'] as List? ?? [];
    final String imageUrl = images.isNotEmpty ? images[0] : "";
    
    // Updated to use 'username' as requested, with fallbacks
    final String userName = item['username'] ?? item['userName'] ?? item['donorName'] ?? item['name'] ?? "Donor";
    final String userImage = item['userImage'] ?? item['donorImage'] ?? item['profilePicture'] ?? "";
    final String userRating = (item['userRating'] ?? item['donorRating'] ?? item['averageRating'] ?? "4.5").toString();
    final String expiry = item['expiry'] ?? "4h";
    final String distance = item['distance'] != null ? "${item['distance']}km away" : "0.3km away";
    final String itemCategory = item['category'] ?? "General";

    return InkWell(
      onTap: () =>
          Navigator.pushNamed(context, '/donation-detail', arguments: item),
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
                      color: const Color(0xFFFFF3E0),
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                ),
                // "Free" tag
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
                        "Posted by you",
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                // Expiry tag
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "Exp. $expiry",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                  Text(
                    item['title'] ?? "Item",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$itemCategory • $distance",
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
                              isPostedByMe ? "You" : userName,
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
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/donation-detail',
                            arguments: item,
                          ),
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
