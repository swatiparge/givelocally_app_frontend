import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../routes/app_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donations_provider.dart';
import '../../providers/preferences_provider.dart';
import 'dart:math';
import '../../services/api_service.dart';
import '../ListView/get_started_cards.dart';
import '../ListView/donation_item_card.dart';
import '../ListView/urgent_blood_request_card.dart';

/// Home screen list content with real-time Firestore streams
///
/// Uses StreamBuilder with Riverpod providers for real-time updates
/// instead of cached Future-based API calls
class HomeListContent extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(userIdProvider);

    return RefreshIndicator(
      onRefresh: () async {
        // Trigger refresh via Riverpod provider
        ref.read(donationRefreshProvider.notifier).refresh();
      },
      child: searchQuery != null && searchQuery!.isNotEmpty
          ? _buildSearchResults(context, ref, currentUserId)
          : _buildCategoryLists(context, ref, currentUserId),
    );
  }

  Widget _buildCategoryLists(
    BuildContext context,
    WidgetRef ref,
    String? currentUserId,
  ) {
    final coords = (lat: lat, lng: lng);
    final getStartedAsync = ref.watch(getStartedNotifierProvider);

    return ListView(
      children: [
        // Get Started section - only show for first-time users
        getStartedAsync.when(
          data: (hasSeen) {
            if (hasSeen) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader("Get Started", showSeeAll: false),
                const GetStartedCards(),
                const SizedBox(height: 8),
                // Dismiss button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextButton.icon(
                    onPressed: () {
                      ref
                          .read(getStartedNotifierProvider.notifier)
                          .markAsSeen();
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text("Dismiss"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        _buildHeader(
          "Urgent Blood Requests",
          onSeeAll: () =>
              _navigateToViewAll(context, "All Blood Requests", "blood"),
        ),
        _buildBloodRequestsSection(context, ref, coords, currentUserId),

        _buildHeader(
          "Food Donations",
          onSeeAll: () =>
              _navigateToViewAll(context, "All Food Donations", "food"),
        ),
        _buildFoodDonationsSection(ref, coords, currentUserId),

        _buildHeader(
          "Other Items",
          onSeeAll: () => _navigateToViewAll(
            context,
            "All Other Items",
            "",
            list: ["appliances", "stationery"],
          ),
        ),
        _buildOtherItemsSection(ref, coords, currentUserId),

        const SizedBox(height: 100),
      ],
    );
  }

  /// Build blood requests section with real-time stream
  Widget _buildBloodRequestsSection(
    BuildContext context,
    WidgetRef ref,
    ({double lat, double lng}) coords,
    String? currentUserId,
  ) {
    final bloodStream = ref.watch(refreshableBloodRequestsProvider(coords));

    return bloodStream.when(
      data: (snapshot) {
        final items = _applySorting(snapshot.toDonationList());

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "No urgent requests in your immediate area",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          );
        }

        final item = items[0];
        final isPostedByMe =
            currentUserId != null &&
            (item['donorId'] == currentUserId ||
                item['userId'] == currentUserId);

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
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          "Failed to load blood requests: $error",
          style: const TextStyle(color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Build food donations section with real-time stream
  Widget _buildFoodDonationsSection(
    WidgetRef ref,
    ({double lat, double lng}) coords,
    String? currentUserId,
  ) {
    final foodStream = ref.watch(refreshableFoodDonationsProvider(coords));

    return foodStream.when(
      data: (snapshot) => _buildCategoryList(
        snapshot.toDonationList(),
        limit: 5,
        currentUserId: currentUserId,
      ),
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const SizedBox(
        height: 100,
        child: Center(child: Text("No food donations nearby")),
      ),
    );
  }

  /// Build other items section with real-time stream
  Widget _buildOtherItemsSection(
    WidgetRef ref,
    ({double lat, double lng}) coords,
    String? currentUserId,
  ) {
    final otherStream = ref.watch(refreshableOtherItemsProvider(coords));

    return otherStream.when(
      data: (snapshot) => _buildCategoryList(
        snapshot.toDonationList(),
        limit: 5,
        currentUserId: currentUserId,
      ),
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const SizedBox(
        height: 100,
        child: Center(child: Text("No items nearby")),
      ),
    );
  }

  /// Build search results (uses API for fuzzy search)
  Widget _buildSearchResults(
    BuildContext context,
    WidgetRef ref,
    String? currentUserId,
  ) {
    // Search still uses API for fuzzy matching
    final searchFuture = ref
        .read(apiServiceProvider)
        .searchDonations(
          searchQuery: searchQuery,
          lat: lat,
          lng: lng,
          limit: 20,
        );

    return FutureBuilder<List<dynamic>>(
      future: searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error searching: ${snapshot.error}"));
        }

        final rawItems = snapshot.data ?? [];
        final items = _applySorting(rawItems.cast<Map<String, dynamic>>());

        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                "No donations found matching your search.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isPostedByMe =
                currentUserId != null &&
                (item['donorId'] == currentUserId ||
                    item['userId'] == currentUserId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildSearchResultItem(context, item, isPostedByMe),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResultItem(
    BuildContext context,
    dynamic item,
    bool isPostedByMe,
  ) {
    final donorName =
        item['donor_name'] ??
        item['donorName'] ??
        item['userName'] ??
        item['username'] ??
        "Donor";

    return InkWell(
      onTap: () => context.goToDonationDetail(item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
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
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  width: 80,
                  height: 80,
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? "No Title",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${item['category'] ?? 'Other'} • $donorName",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  if (item['distance'] != null)
                    Text(
                      _formatDistance(item['distance']),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (isPostedByMe)
              const Chip(
                label: Text(
                  "Mine",
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: Colors.blue,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  /// Build horizontal category list with donation cards
  Widget _buildCategoryList(
    List<Map<String, dynamic>> items, {
    required int limit,
    required String? currentUserId,
  }) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text("No items nearby")),
      );
    }

    final sortedItems = _applySorting(items);
    final displayItems = sortedItems.take(limit).toList();

    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          final item = displayItems[index];
          final isPostedByMe =
              currentUserId != null &&
              (item['donorId'] == currentUserId ||
                  item['userId'] == currentUserId);
          final donorName =
              item['donor_name'] ??
              item['donorName'] ??
              item['userName'] ??
              item['username'] ??
              "Donor";

          return DonationItemCard(
            key: ValueKey(item['id']), // Important for list optimization
            title: item['title'] ?? "Item",
            category: item['category'] ?? "Other",
            distance: _formatDistance(item['distance']),
            donorName: donorName,
            imageUrl: _firstImageUrl(item),
            isPostedByMe: isPostedByMe,
            onTap: () => context.goToDonationDetail(item),
          );
        },
      ),
    );
  }

  /// Sort items by creation date (newest first)
  List<Map<String, dynamic>> _applySorting(List<Map<String, dynamic>> items) {
    final sortedItems = List<Map<String, dynamic>>.from(items);
    sortedItems.sort((a, b) {
      final dateA = _extractDateTime(a);
      final dateB = _extractDateTime(b);
      return dateB.compareTo(dateA);
    });
    return sortedItems;
  }

  DateTime _extractDateTime(Map<String, dynamic> item) {
    final dateData =
        item['createdAt'] ??
        item['created_at'] ??
        item['timestamp'] ??
        (item['pickup_window'] != null
            ? item['pickup_window']['start_date']
            : null);

    if (dateData == null) return DateTime(2000);

    if (dateData is Map) {
      final seconds = dateData['_seconds'] ?? dateData['seconds'] ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }

    if (dateData is int) {
      if (dateData < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(dateData * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(dateData);
    }

    if (dateData is String) {
      return DateTime.tryParse(dateData) ?? DateTime(2000);
    }

    return DateTime(2000);
  }

  String _formatDistance(dynamic value) {
    if (value is num) return "${value.toStringAsFixed(1)}km";
    return "";
  }

  String _firstImageUrl(Map<String, dynamic> item) {
    try {
      final images = item['images'];
      if (images is List && images.isNotEmpty) return images[0];
    } catch (_) {}
    return "https://via.placeholder.com/200x120";
  }

  void _navigateToViewAll(
    BuildContext context,
    String title,
    String cat, {
    List<String>? list,
  }) {
    context.goToViewAll(
      title: title,
      category: cat,
      categories: list,
      lat: lat,
      lng: lng,
    );
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

/// Provider for ApiService
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
