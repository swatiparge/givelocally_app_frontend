// lib/widgets/app_header.dart

import 'package:flutter/material.dart';
import '../screens/notifications/notifications_screen.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String location;
  final VoidCallback onNotificationTap;
  final VoidCallback onMenuTap;

  const AppHeader({
    super.key,
    this.location = "Indiranagar, Bangalore",
    required this.onNotificationTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      // FIXED: Disable automatic leading/drawer icons to prevent duplicates
      automaticallyImplyLeading: false,
      actions: [const SizedBox.shrink()],
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          // --- LEFT SIDE: LOGO & LOCATION ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'GiveLocally',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
                InkWell(
                  onTap: () {
                    // Logic for WF-14: Location Picker
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          location,
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.green.shade600),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- RIGHT SIDE: NOTIFICATIONS & MENU (Clustered) ---
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Notification Bell
              _buildHeaderAction(
                icon: Icons.notifications_none_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                },
                hasBadge: true,
              ),
              const SizedBox(width: 10), // Controlled spacing between icons
              // 2. Single Menu Button
              _buildHeaderAction(
                icon: Icons.menu_rounded,
                onTap: onMenuTap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper to build consistent, tight action buttons without extra padding
  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.black87, size: 22),
            if (hasBadge)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 12);
}
