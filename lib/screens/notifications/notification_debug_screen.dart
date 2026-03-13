import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/notification_provider.dart';
import '../../services/fcm_service.dart';

/// Debug screen to diagnose notification issues
class NotificationDebugScreen extends ConsumerWidget {
  const NotificationDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final notificationState = ref.watch(notificationNotifierProvider);
    final fcmService = ref.watch(fcmServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current User Info
          _buildCard('Current User', [
            _buildRow('UID', currentUser?.uid ?? 'Not logged in'),
            _buildRow('Email', currentUser?.email ?? 'Not logged in'),
          ]),
          const SizedBox(height: 16),

          // FCM Status
          _buildCard('FCM Status', [
            _buildRow('Available', '${fcmService.isAvailable}'),
            _buildRow(
              'Token',
              fcmService.currentToken?.isNotEmpty == true
                  ? '${fcmService.currentToken!.substring(0, 20)}...'
                  : 'No token',
            ),
          ]),
          const SizedBox(height: 16),

          // Notification Stats
          _buildCard('Notification Stats', [
            _buildRow('Total', '${notificationState.notifications.length}'),
            _buildRow('Unread', '${notificationState.unreadCount}'),
            _buildRow('Has New', '${notificationState.hasNewNotification}'),
          ]),
          const SizedBox(height: 16),

          // Recent Notifications
          if (notificationState.notifications.isNotEmpty) ...[
            const Text(
              'Recent Notifications (Last 5):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...notificationState.notifications.take(5).map((notification) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRow('Type', notification['type'] ?? 'unknown'),
                      _buildRow('Title', notification['title'] ?? ''),
                      _buildRow('Body', notification['body'] ?? ''),
                      _buildRow('ID', notification['id'] ?? ''),
                      if (notification['donationId'] != null)
                        _buildRow('Donation ID', notification['donationId']!),
                      if (notification['senderId'] != null)
                        _buildRow('Sender', notification['senderId']!),
                      if (notification['donorId'] != null)
                        _buildRow('Donor', notification['donorId']!),
                      if (notification['receiverId'] != null)
                        _buildRow('Receiver', notification['receiverId']!),
                    ],
                  ),
                ),
              );
            }),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No notifications yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Actions
          ElevatedButton.icon(
            onPressed: () {
              ref.read(notificationNotifierProvider.notifier).setLoading(false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Try pulling to refresh in notifications screen',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Force Refresh (Go to Notifications)'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(notificationNotifierProvider.notifier).markAllAsRead();
            },
            icon: const Icon(Icons.done_all),
            label: const Text('Mark All as Read'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // Clear all notifications
              ref
                  .read(notificationNotifierProvider.notifier)
                  .setNotifications([]);
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear All Notifications'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.length > 50 ? '${value.substring(0, 50)}...' : value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
