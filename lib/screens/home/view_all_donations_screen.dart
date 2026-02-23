import 'package:flutter/material.dart';
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
                    return _buildVerticalListCard(context, item);
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

  Widget _buildVerticalListCard(BuildContext context, dynamic item) {
    final images = item['images'] as List? ?? [];
    final String imageUrl = images.isNotEmpty ? images[0] : "";

    return InkWell(
      onTap: () =>
          Navigator.pushNamed(context, '/donation-detail', arguments: item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  color: Colors.grey.shade100,
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? "Item",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${item['category']} • Nearby",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/donation-detail',
                      arguments: item,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F8E9),
                      foregroundColor: Colors.green,
                      elevation: 0,
                    ),
                    child: const Text("Request"),
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
