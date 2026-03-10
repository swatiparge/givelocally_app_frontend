import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donations_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/main_bottom_nav.dart'; // Footer
import '../../widgets/home_search_bar.dart';
import '../../widgets/ListView/view_toggle.dart';
import '../../widgets/ListView/home_list_content.dart';
import '../../widgets/donation/category_selection_modal.dart';
import 'map_view_screen.dart';
import '../../navigation/route_observer.dart';
import '../../config/default_location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// geocoding removed - cost optimization (AGENTS.md 8.3.2)
import '../../services/geolocation_service.dart';
import '../../services/api_service.dart';

import '../profile/profile_page.dart';
import '../profile/my_donations_screen.dart';
import '../profile/received_items_screen.dart';
import '../chat/chat_list_screen.dart';
import '../donation/request_item_screen.dart';
import '../auth/location_confirmation_screen.dart';
import 'community_coming_soon_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  bool _isListView = true;
  String _searchQuery = "";
  int _refreshKey = 0; // Used to force HomeListContent rebuild

  String _currentAddress = kDefaultAddress;
  LatLng _currentPosition = const LatLng(kDefaultLat, kDefaultLng);

  @override
  void initState() {
    super.initState();
    _detectAndSetLocation();
    // Initialize chat provider to start polling for messages
    // This ensures unread counts and chat list stay synchronized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatListProvider.notifier).loadChats();
      }
    });
  }

  Future<void> _detectAndSetLocation() async {
    final pos = await GeolocationService.getCurrentPosition();
    if (pos == null || !mounted) return;

    final latLng = LatLng(pos.latitude, pos.longitude);

    // COST OPTIMIZATION: Do NOT call geocoding on map load (AGENTS.md 8.3.2)
    // Geocoding should ONLY be called when user confirms a location
    // This saves ~₹500/month at scale
    setState(() {
      _currentPosition = latLng;
      // Address will be shown from user?.area in build()
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (!mounted) return;
    // Clear API cache when returning from donation creation
    // This ensures newly created donations appear immediately
    ApiService().clearCache();
    // Trigger Riverpod refresh for real-time Firestore streams
    ref.read(donationRefreshProvider.notifier).refresh();
    setState(() {
      _refreshKey++; // Force HomeListContent to rebuild and fetch fresh data
    });
  }

  // --- DRAWER HELPERS ---

  Widget _drawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool hasNotification = false,
    bool isComingSoon = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: Colors.blueGrey.shade700, size: 24),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1A1C1E),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isComingSoon) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFA5D6A7), width: 0.5),
              ),
              child: const Text(
                "Coming Soon",
                style: TextStyle(
                  fontSize: 8,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasNotification)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20),
        ],
      ),
      onTap: isComingSoon ? null : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref
        .watch(userModelProvider)
        .when(
          data: (user) => user,
          loading: () => null,
          error: (_, __) => null,
        );

    return Scaffold(
      key: _scaffoldKey,
      appBar: (_currentIndex == 3 || _currentIndex == 2 || _currentIndex == 1)
          ? null
          : AppHeader(
              location: user?.area ?? _currentAddress,
              onMenuTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              onLocationTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LocationConfirmationScreen(
                      navigateToProfileSetup: false,
                    ),
                  ),
                ).then((_) {
                  _detectAndSetLocation();
                });
              },
            ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // --- GREEN HEADER SECTION ---
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 35,
                              backgroundImage: user?.profilePicture != null
                                  ? NetworkImage(user!.profilePicture!)
                                  : const NetworkImage(
                                      'https://via.placeholder.com/150',
                                    ),
                            ),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              height: 16,
                              width: 16,
                              decoration: BoxDecoration(
                                color: const Color(0xFF81C784),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user?.name ?? 'User Name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${user?.karmaPoints ?? 0} Karma",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Level ${((user?.karmaPoints ?? 0) / 100).floor() + 1} Donor",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- MENU ITEMS ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _drawerSectionTitle("MY ACTIVITY"),
                  _drawerItem(Icons.person_outline, "My Profile", () {
                    Navigator.pop(context); // Close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfilePage(),
                      ),
                    );
                  }),
                  _drawerItem(
                    Icons.volunteer_activism_outlined,
                    "My Donations",
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyDonationsScreen(),
                        ),
                      );
                    },
                  ),
                  _drawerItem(
                    Icons.inventory_2_outlined,
                    "My Received Items",
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReceivedItemsScreen(),
                        ),
                      );
                    },
                  ),
                  _drawerItem(
                    Icons.shopping_bag_outlined,
                    "Request an Item",
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RequestItemScreen(),
                        ),
                      );
                    },
                  ),

                  const Divider(height: 32, indent: 24, endIndent: 24),

                  _drawerSectionTitle("COMMUNITY"),
                  _drawerItem(
                    Icons.stars_outlined,
                    "Karma & Badges",
                    () {
                      Navigator.pop(context);
                    },
                    hasNotification: true,
                    isComingSoon: true,
                  ),
                  _drawerItem(Icons.leaderboard_outlined, "Leaderboard", () {
                    Navigator.pop(context);
                  }, isComingSoon: true),

                  const Divider(height: 32, indent: 24, endIndent: 24),

                  _drawerSectionTitle("APP INFO"),
                  _drawerItem(Icons.settings_outlined, "Settings", () {
                    Navigator.pop(context);
                  }, isComingSoon: true),
                  _drawerItem(Icons.help_outline_rounded, "Help & Support", () {
                    Navigator.pop(context);
                  }),
                ],
              ),
            ),

            // --- LOGOUT BUTTON ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: InkWell(
                onTap: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                child: Row(
                  children: const [
                    Icon(Icons.logout_rounded, color: Color(0xFFD32F2F)),
                    SizedBox(width: 16),
                    Text(
                      "Logout",
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_currentIndex == 0)
            HomeSearchBar(
              onSearchChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              onFilterTap: () {},
            ),
          if (_currentIndex == 0)
            ViewToggle(
              isListView: _isListView,
              onChanged: (val) => setState(() => _isListView = val),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _isListView
                    ? HomeListContent(
                        key: ValueKey(
                          _refreshKey,
                        ), // Force rebuild when refreshKey changes
                        lat: _currentPosition.latitude,
                        lng: _currentPosition.longitude,
                        searchQuery: _searchQuery,
                      )
                    : MapViewScreen(initialPosition: _currentPosition),
                const CommunityComingSoonScreen(),
                const ChatListScreen(),
                const ProfilePage(showBackButton: false),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const CategorySelectionModal(),
          );
        },
        backgroundColor: Colors.green.shade600,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
        elevation: 4,
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
