// lib/widgets/ListView/home_list_content.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../ListView/get_started_cards.dart';
import '../ListView/donation_item_card.dart';
import '../ListView/urgent_blood_request_card.dart';
import '../../screens/home/view_all_donations_screen.dart'; // Ensure this exists

class HomeListContent extends StatefulWidget {
  const HomeListContent({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  State<HomeListContent> createState() => _HomeListContentState();
}

class _HomeListContentState extends State<HomeListContent> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        if (!mounted) return;
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 250));
      },
      child: ListView(
        children: [
          _buildHeader("Get Started", showSeeAll: false),
          const GetStartedCards(),

          // const CategoryFilters(),
          _buildHeader(
            "Urgent Blood Requests",
            onSeeAll: () => _navigateToViewAll("All Blood Requests", "blood"),
          ),

          FutureBuilder<List<dynamic>>(
            future: _apiService.fetchNearbyDonations(
              lat: widget.lat,
              lng: widget.lng,
              category: "blood",
              // Backend allows radiusKm 1-50
              radiusKm: 50.0,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "Failed to load blood requests",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                // FIXED: Strictly show only ONE card on home page
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/donation-detail',
                      arguments: snapshot.data![0],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: UrgentBloodRequestCard(donation: snapshot.data![0]),
                  ),
                );
              }

              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "No urgent requests in your immediate area",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),

          _buildHeader(
            "Food Donations",
            onSeeAll: () => _navigateToViewAll("All Food Donations", "food"),
          ),
          _buildCategoryList(["food"], limit: 5),

          _buildHeader(
            "Other Items",
            onSeeAll: () => _navigateToViewAll(
              "All Other Items",
              "",
              list: ["appliances", "stationery"],
            ),
          ),
          // Combined Appliances and Stationery
          _buildCategoryList(["appliances", "stationery"], limit: 5),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _navigateToViewAll(String title, String cat, {List<String>? list}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewAllDonationsScreen(
          title: title,
          category: cat,
          categories: list,
          lat: widget.lat,
          lng: widget.lng,
        ),
      ),
    );
  }

  Widget _buildCategoryList(List<String> categories, {int limit = 5}) {
    return FutureBuilder<List<dynamic>>(
      future: _apiService.fetchMultipleCategories(
        lat: widget.lat,
        lng: widget.lng,
        categories: categories,
        radiusKm: 50,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: 100,
            child: Center(child: Text("No items nearby")),
          );
        }

        // Limit the items shown on home page
        final items = snapshot.data!.take(limit).toList();

        return SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return DonationItemCard(
                title: item['title'] ?? "Item",
                category: item['category'] ?? "Other",
                distance: _formatDistance(item['distance']),
                donorName: item['donorName'] ?? "Donor",
                imageUrl: _firstImageUrl(item),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/donation-detail',
                  arguments: item,
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDistance(dynamic value) {
    if (value is num) return "${value.toStringAsFixed(1)}km";
    if (value is String && value.isNotEmpty) return value;
    return "";
  }

  String _firstImageUrl(dynamic item) {
    try {
      final images = (item is Map) ? item['images'] : null;
      if (images is List && images.isNotEmpty) {
        for (final v in images) {
          if (v is! String) continue;
          final s = v.trim();
          if (!s.startsWith('http')) continue;
          final lower = s.toLowerCase();
          // Skip legacy/test placeholders
          if (lower.contains('example.com')) continue;
          if (lower.contains('via.placeholder')) continue;
          return s;
        }
      }
      if (images is String && images.startsWith('http')) return images;
    } catch (_) {
      // ignore
    }
    return "https://via.placeholder.com/200x120";
  }

  Widget _buildHeader(
    String title, {
    bool showSeeAll = true,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1C1E),
            ),
          ),
          if (showSeeAll)
            InkWell(
              onTap: onSeeAll,
              child: const Text(
                "See all",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

//
// class CategoryFilters extends StatelessWidget {
//   const CategoryFilters({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: Row(
//         children: [
//           _chip("Category"),
//           const SizedBox(width: 8),
//           _chip("Distance"),
//         ],
//       ),
//     );
//   }
//
//   Widget _chip(String text) => Expanded(
//     child: Container(
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: Border.all(color: Colors.grey.shade300),
//         borderRadius: BorderRadius.circular(8),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.02),
//             blurRadius: 4,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: const Row(
//         children: [
//           Text("Category", style: TextStyle(fontWeight: FontWeight.w500)),
//           Spacer(),
//           Icon(Icons.arrow_drop_down, color: Colors.grey),
//         ],
//       ),
//     ),
//   );
// }
