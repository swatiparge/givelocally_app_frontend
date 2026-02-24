// lib/widgets/ListView/home_list_content.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../ListView/get_started_cards.dart';
import '../ListView/donation_item_card.dart';
import '../ListView/urgent_blood_request_card.dart';
import '../../screens/home/view_all_donations_screen.dart';

class HomeListContent extends StatefulWidget {
  const HomeListContent({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  State<HomeListContent> createState() => _HomeListContentState();
}

class _HomeListContentState extends State<HomeListContent> {
  final ApiService _apiService = ApiService();
  
  // Cache the futures in state to prevent re-fetching on every rebuild
  late Future<List<dynamic>> _bloodRequestsFuture;
  late Future<List<dynamic>> _foodDonationsFuture;
  late Future<List<dynamic>> _otherItemsFuture;

  @override
  void initState() {
    super.initState();
    _initFutures();
  }

  void _initFutures() {
    _bloodRequestsFuture = _apiService.fetchNearbyDonations(
      lat: widget.lat,
      lng: widget.lng,
      category: "blood",
      radiusKm: 50.0,
    );
    
    _foodDonationsFuture = _apiService.fetchMultipleCategories(
      lat: widget.lat,
      lng: widget.lng,
      categories: ["food"],
      radiusKm: 50,
    );
    
    _otherItemsFuture = _apiService.fetchMultipleCategories(
      lat: widget.lat,
      lng: widget.lng,
      categories: ["appliances", "stationery"],
      radiusKm: 50,
    );
  }

  @override
  void didUpdateWidget(HomeListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only refresh if location changed significantly (> 500 meters)
    final distance = _calculateDistance(
      oldWidget.lat, oldWidget.lng,
      widget.lat, widget.lng,
    );
    
    if (distance > 0.5) {
      debugPrint("HOME_LIST_CONTENT: Significant movement detected ($distance km). Refreshing futures.");
      setState(() {
        _initFutures();
      });
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p)/2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.firebaseUser?.uid;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _initFutures();
        });
        await _bloodRequestsFuture;
        await _foodDonationsFuture;
        await _otherItemsFuture;
      },
      child: ListView(
        children: [
          _buildHeader("Get Started", showSeeAll: false),
          const GetStartedCards(),

          _buildHeader(
            "Urgent Blood Requests",
            onSeeAll: () => _navigateToViewAll("All Blood Requests", "blood"),
          ),

          FutureBuilder<List<dynamic>>(
            future: _bloodRequestsFuture,
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
                final item = snapshot.data![0];
                final isPostedByMe = currentUserId != null && 
                    (item['donorId'] == currentUserId || item['userId'] == currentUserId);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/donation-detail',
                      arguments: item,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: UrgentBloodRequestCard(
                      donation: item,
                      isPostedByMe: isPostedByMe,
                    ),
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
          _buildCategoryList(_foodDonationsFuture, limit: 5),

          _buildHeader(
            "Other Items",
            onSeeAll: () => _navigateToViewAll(
              "All Other Items",
              "",
              list: ["appliances", "stationery"],
            ),
          ),
          _buildCategoryList(_otherItemsFuture, limit: 5),

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

  Widget _buildCategoryList(Future<List<dynamic>> future, {int limit = 5}) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.firebaseUser?.uid;

    return FutureBuilder<List<dynamic>>(
      future: future,
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

        final items = snapshot.data!.take(limit).toList();

        return SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isPostedByMe = currentUserId != null && 
                  (item['donorId'] == currentUserId || item['userId'] == currentUserId);

              final userName = item['userName'] ?? item['username'] ?? item['donorName'] ?? "Donor";

              return DonationItemCard(
                title: item['title'] ?? "Item",
                category: item['category'] ?? "Other",
                distance: _formatDistance(item['distance']),
                donorName: userName,
                imageUrl: _firstImageUrl(item),
                isPostedByMe: isPostedByMe,
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
    return "";
  }

  String _firstImageUrl(dynamic item) {
    try {
      final images = item['images'];
      if (images is List && images.isNotEmpty) return images[0];
    } catch (_) {}
    return "https://via.placeholder.com/200x120";
  }

  Widget _buildHeader(String title, {bool showSeeAll = true, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
          if (showSeeAll)
            InkWell(
              onTap: onSeeAll,
              child: const Text("See all", style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
