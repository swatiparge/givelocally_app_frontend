import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../auth/profile_setup_screen.dart';
import 'my_donations_screen.dart';
import 'received_items_screen.dart';
import 'requested_items_screen.dart';

class ProfilePage extends StatefulWidget {
  final bool showBackButton;
  const ProfilePage({super.key, this.showBackButton = true});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  String _getJoinedDate(UserModel? user) {
    if (user?.createdAt != null) {
      return DateFormat("MMM ''yy").format(user!.createdAt);
    }
    return "Jan '24"; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.userModel;
    final uid = authService.firebaseUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.showBackButton ? const BackButton(color: Colors.black) : null,
        title: const Text("My Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(user),
            const SizedBox(height: 16),
            _buildStatsGrid(user),
            const SizedBox(height: 16),
            _buildQuickStatsCard(),
            const SizedBox(height: 16),
            _buildBadgesSectionCard(),
            const SizedBox(height: 16),
            _buildTabsSection(),
            _buildTabContentView(uid),
            const SizedBox(height: 16),
            _buildAccountSettingsCard(authService),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel? user) {
    final joinedDate = _getJoinedDate(user);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade100, width: 2),
                ),
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.grey.shade100,
                  backgroundImage: user?.profilePicture != null 
                      ? NetworkImage(user!.profilePicture!) 
                      : const NetworkImage('https://via.placeholder.com/150'),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                  child: const Icon(Icons.camera_alt, size: 18, color: Color(0xFF66BB6A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(user?.name ?? "User Name", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
              const SizedBox(width: 6),
              const Icon(Icons.verified, color: Color(0xFF66BB6A), size: 22),
            ],
          ),
          const SizedBox(height: 4),
          Text("${user?.area ?? 'Location'} • Joined $joinedDate", style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 24),
          _buildEditButton(),
        ],
      ),
    );
  }

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
          );
        },
        icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
        label: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF66BB6A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(UserModel? user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statCard("⭐ ${user?.averageRating.toStringAsFixed(1) ?? '0.0'}", "RATING"),
          const SizedBox(width: 12),
          _statCard("🌱 ${user?.karmaPoints ?? 0}", "KARMA", iconColor: const Color(0xFF66BB6A)),
        ],
      ),
    );
  }

  Widget _statCard(String val, String label, {Color? iconColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: iconColor ?? const Color(0xFF1A1C1E))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quickStat("18", "Donations", Icons.volunteer_activism_outlined),
          _quickStat("5", "Requested", Icons.shopping_bag_outlined),
          _quickStat("12", "Received", Icons.archive_outlined),
          _quickStat("98%", "Success", Icons.check_circle_outline),
        ],
      ),
    );
  }

  Widget _quickStat(String val, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blueGrey.shade300),
        const SizedBox(height: 10),
        Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF1A1C1E))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildBadgesSectionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("BADGES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8, color: Color(0xFF1A1C1E))),
              Text("View all", style: TextStyle(color: Color(0xFF66BB6A), fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _badgeItem("Top Giver", Icons.card_giftcard, Colors.orange),
              _badgeItem("Verified", Icons.shield_outlined, Colors.blue),
              _badgeItem("Speedy", Icons.flash_on, Colors.amber),
            ],
          )
        ],
      ),
    );
  }

  Widget _badgeItem(String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          height: 60, width: 60,
          decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A4C4E))),
      ],
    );
  }

  Widget _buildTabsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) => setState(() {}),
        labelColor: const Color(0xFF66BB6A),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF66BB6A),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        tabs: const [
          Tab(text: "My Donations"),
          Tab(text: "Received"),
          Tab(text: "Requests"),
        ],
      ),
    );
  }

  Widget _buildTabContentView(String? uid) {
    if (uid == null) return const SizedBox.shrink();
    
    switch (_tabController.index) {
      case 0:
        return _buildMyDonationsPreview(uid);
      case 1:
        return _buildReceivedItemsPreview(uid);
      case 2:
        return _buildEmptyRequestsView();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmptyReceivedView() {
    return _buildTabEmptyState(
      icon: Icons.archive_outlined,
      title: "No items received yet",
      subtitle: "Items you receive from donors will appear here.",
    );
  }

  Widget _buildEmptyRequestsView() {
    return _buildTabEmptyState(
      icon: Icons.flag_outlined,
      title: "No requests found",
      subtitle: "Your active requests will appear here.",
    );
  }

  Widget _buildTabEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedItemsPreview(String userId) {
    return FutureBuilder<List<dynamic>>(
      future: _apiService.getReceivedItems("completed"),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF66BB6A))),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _buildEmptyReceivedView();
        }

        final displayItems = items.take(2).toList();

        return Column(
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: displayItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final data = displayItems[i] as Map<String, dynamic>;
                return _buildTransactionItemCard(data);
              },
            ),
            if (items.length > 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ReceivedItemsScreen()),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text("View All Received Items", style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 16, color: Color(0xFF2E7D32)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionItemCard(Map<String, dynamic> data) {
    final title = data['donationTitle'] ?? data['title'] ?? "Item";
    final donorName = data['donorName'] ?? "Donor";
    final imageUrl = data['donationImage'] ?? data['image'] ?? "";
    final category = (data['category'] ?? '').toString().toLowerCase();
    final isBlood = category.contains('blood');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 68, height: 68,
              color: isBlood ? const Color(0xFFFFEBEE) : const Color(0xFFF8F9FA),
              child: imageUrl.isNotEmpty && imageUrl.startsWith('http')
                  ? Image.network(
                      imageUrl, 
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(category, isBlood),
                    )
                  : _buildPlaceholder(category, isBlood),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1C1E))),
                const SizedBox(height: 4),
                Text("Gifted by $donorName", style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 20),
        ],
      ),
    );
  }

  Widget _buildMyDonationsPreview(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF66BB6A))),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyDonationView();
        }

        final displayDocs = docs.take(2).toList();

        return Column(
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: displayDocs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final data = displayDocs[i].data() as Map<String, dynamic>;
                return _buildDonationItemCard(data);
              },
            ),
            if (docs.length > 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MyDonationsScreen()),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text("View All Donations", style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 16, color: Color(0xFF2E7D32)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyDonationView() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, spreadRadius: 4),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite, color: Colors.green.shade600, size: 64),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.card_giftcard, color: Colors.grey.shade300, size: 24),
                    const SizedBox(width: 12),
                    Icon(Icons.volunteer_activism, color: Colors.grey.shade300, size: 24),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text("No donations yet", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Be the first to help your neighbors by sharing items you don\'t need. Every small gift makes a big impact.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Donate Now"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF66BB6A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDonationItemCard(Map<String, dynamic> item) {
    final images = item['images'] as List?;
    
    // Improved URL validation to catch "null" strings or broken fields
    String imageUrl = '';
    if (images != null && images.isNotEmpty && images[0] != null) {
      final String firstImg = images[0].toString();
      if (firstImg.isNotEmpty && firstImg != 'null' && firstImg != 'undefined') {
        imageUrl = firstImg;
      }
    }

    final category = (item['category'] ?? '').toString().toLowerCase();
    final title = (item['title'] ?? '').toString().toLowerCase();
    
    // Robust detection for blood items
    final isBlood = category.contains('blood') || title.contains('blood');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 68, height: 68,
              // Background color based on category helps UI feel responsive even if image fails
              color: isBlood ? const Color(0xFFFFEBEE) : const Color(0xFFF8F9FA),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl, 
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(category, isBlood),
                    )
                  : _buildPlaceholder(category, isBlood),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'] ?? "Item", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1C1E))),
                const SizedBox(height: 4),
                Text(item['description'] ?? "", style: const TextStyle(fontSize: 13, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.more_horiz, color: Colors.grey), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String category, bool isBlood) {
    IconData icon;
    Color color;

    if (isBlood) {
      icon = Icons.water_drop;
      color = Colors.redAccent;
    } else if (category.contains('food')) {
      icon = Icons.restaurant;
      color = Colors.orangeAccent;
    } else if (category.contains('appliance')) {
      icon = Icons.devices;
      color = Colors.blueAccent;
    } else if (category.contains('stationery') || category.contains('book')) {
      icon = Icons.menu_book;
      color = Colors.greenAccent;
    } else {
      icon = Icons.inventory_2_outlined;
      color = Colors.blueGrey;
    }

    return Icon(icon, color: color.withOpacity(0.8), size: 30);
  }

  Widget _buildAccountSettingsCard(AuthService auth) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ACCOUNT & SETTINGS", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          _settingsItem(Icons.history_rounded, "Transaction History"),
          _settingsItem(Icons.gavel_rounded, "Dispute Center"),
          _settingsItem(Icons.payment_rounded, "Payment Methods"),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFFF1F1F1)),
          ),
          InkWell(
            onTap: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: const [
                  Icon(Icons.logout_rounded, color: Color(0xFFD32F2F), size: 24),
                  SizedBox(width: 16),
                  Text("Log Out", style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _settingsItem(IconData icon, String title) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: Colors.blueGrey.shade700),
    ),
    title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1C1E))),
    trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFBDBDBD)),
    onTap: () {},
  );
}
