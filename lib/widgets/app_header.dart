// lib/widgets/app_header.dart
// App header with notification badge using Riverpod

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notification_provider.dart';
import '../routes/app_router.dart';

class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String location;
  final VoidCallback onMenuTap;
  final VoidCallback? onLocationTap;

  const AppHeader({
    super.key,
    this.location = "Indiranagar, Bangalore",
    required this.onMenuTap,
    this.onLocationTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch unread notification count
    final unreadCount = ref.watch(unreadCountProvider);
    final hasNewNotification = ref.watch(hasNewNotificationProvider);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
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
                  onTap: onLocationTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.green.shade600,
                      ),
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
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.green.shade600,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- RIGHT SIDE: NOTIFICATIONS & MENU ---
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification Bell with Badge
              _buildNotificationButton(
                context: context,
                unreadCount: unreadCount,
                hasNewNotification: hasNewNotification,
                onTap: () => context.push(AppRouter.notifications),
              ),
              const SizedBox(width: 10),
              // Menu Button
              _buildHeaderAction(icon: Icons.menu_rounded, onTap: onMenuTap),
            ],
          ),
        ],
      ),
    );
  }

  /// Build notification button with unread count badge
  Widget _buildNotificationButton({
    required BuildContext context,
    required int unreadCount,
    required bool hasNewNotification,
    required VoidCallback onTap,
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
            Icon(
              Icons.notifications_none_outlined,
              color: Colors.black87,
              size: 22,
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  height: 16,
                  width: 16,
                  decoration: BoxDecoration(
                    color: hasNewNotification ? Colors.red : Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Helper to build consistent action buttons
  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onTap,
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
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 12);
}
