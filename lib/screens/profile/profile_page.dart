import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../auth/profile_setup_screen.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final bool showBackButton;
  const ProfilePage({super.key, this.showBackButton = true});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String _getJoinedDate(UserModel? user) {
    if (user?.createdAt != null) {
      return DateFormat("MMM ''yy").format(user!.createdAt);
    }
    return "Jan '24"; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userModelProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.showBackButton ? const BackButton(color: Colors.black) : null,
        title: const Text("My Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
            _buildAccountSettingsCard(),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BADGES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8, color: Color(0xFF1A1C1E))),
          const SizedBox(height: 8),
          const Text(
            "New achievements are on the horizon! Adding the badges soon",
            style: TextStyle(color: Colors.blueGrey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _badgeItem("Top Giver", Icons.card_giftcard, Colors.orange),
                  _badgeItem("Verified", Icons.shield_outlined, Colors.blue),
                  _badgeItem("Speedy", Icons.flash_on, Colors.amber),
                ],
              ),
              // Blur effect
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
              ),
              // "Arriving Shortly" Overlay
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF66BB6A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Text(
                  "ARRIVING SHORTLY",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
                ),
              ),
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

  Widget _buildAccountSettingsCard() {
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
              await ref.read(authNotifierProvider.notifier).signOut();
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
