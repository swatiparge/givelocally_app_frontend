import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../routes/app_router.dart';
import '../../providers/auth_provider.dart';
import 'dart:math';
import '../../services/api_service.dart';
import '../ListView/get_started_cards.dart';
import '../ListView/donation_item_card.dart';
import '../ListView/urgent_blood_request_card.dart';

class HomeListContent extends ConsumerStatefulWidget {
  const HomeListContent({
    super.key,
    required this.lat,
    required this.lng,
    this.searchQuery,
  });

  final double lat;
  final double lng;
  final String? searchQuery;

  @override
  ConsumerState<HomeListContent> createState() => _HomeListContentState();
}

class _HomeListContentState extends ConsumerState<HomeListContent> {
  final ApiService _apiService = ApiService();
  
  // Cache the futures in state to prevent re-fetching on every rebuild
  late Future<List<dynamic>> _bloodRequestsFuture;
  late Future<List<dynamic>> _foodDonationsFuture;
  late Future<List<dynamic>> _otherItemsFuture;
  Future<List<dynamic>>? _searchResultsFuture;

  @override
  void initState() {
    super.initState();
    _initFutures();
  }

  void _initFutures() {
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _searchResultsFuture = _apiService.searchDonations(
        searchQuery: widget.searchQuery,
        lat: widget.lat,
        lng: widget.lng,
        limit: 20,
      );
    } else {
      _searchResultsFuture = null;
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
  }

  @override
  void didUpdateWidget(HomeListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Refresh if search query changed
    if (oldWidget.searchQuery != widget.searchQuery) {
      setState(() {
        _initFutures();
      });
      return;
    }

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
    final currentUserId = ref.watch(userIdProvider);

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _initFutures();
        });
        if (_searchResultsFuture != null) {
          await _searchResultsFuture;
        } else {
          await _bloodRequestsFuture;
          await _foodDonationsFuture;
          await _otherItemsFuture;
        }
      },
      child: widget.searchQuery != null && widget.searchQuery!.isNotEmpty
          ? _buildSearchResults()
          : ListView(
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
                          onTap: () => context.goToDonationDetail(item),
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

  Widget _buildSearchResults() {
    final currentUserId = ref.watch(userIdProvider);
    
    return FutureBuilder<List<dynamic>>(
      future: _searchResultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text("Error searching: ${snapshot.error}"));
        }
        
        final items = snapshot.data ?? [];
        
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text("No donations found matching your search.", textAlign: TextAlign.center),
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isPostedByMe = currentUserId != null && 
                (item['donorId'] == currentUserId || item['userId'] == currentUserId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildSearchResultItem(item, isPostedByMe),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResultItem(dynamic item, bool isPostedByMe) {
    final userName = item['userName'] ?? item['username'] ?? item['donorName'] ?? "Donor";
    
    return InkWell(
      onTap: () => context.goToDonationDetail(item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _firstImageUrl(item),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], width: 80, height: 80, child: const Icon(Icons.image_not_supported)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? "No Title",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${item['category'] ?? 'Other'} • $userName",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  if (item['distance'] != null)
                    Text(
                      _formatDistance(item['distance']),
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (isPostedByMe)
              const Chip(
                label: Text("Mine", style: TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: Colors.blue,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToViewAll(String title, String cat, {List<String>? list}) {
    context.goToViewAll(
      title: title,
      category: cat,
      categories: list,
      lat: widget.lat,
      lng: widget.lng,
    );
  }

  Widget _buildCategoryList(Future<List<dynamic>> future, {int limit = 5}) {
    final currentUserId = ref.watch(userIdProvider);

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
                onTap: () => context.goToDonationDetail(item),
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
