import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/notification_provider.dart';
import '../../services/fcm_service.dart';

/// Comprehensive FCM Debug Screen
/// Use this to diagnose notification issues
class FcmDebugScreen extends ConsumerWidget {
  const FcmDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final fcmService = ref.watch(fcmServiceProvider);
    final notificationState = ref.watch(notificationNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM Debug'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Current User', [
            _buildRow('UID', currentUser?.uid ?? 'Not logged in'),
            _buildRow('Email', currentUser?.email ?? 'Not logged in'),
          ]),
          const SizedBox(height: 16),
          _buildSection('FCM Status', [
            _buildRow('Available', '${fcmService.isAvailable}'),
            _buildRow(
              'Token',
              fcmService.currentToken?.isNotEmpty == true
                  ? '${fcmService.currentToken!.substring(0, 30)}...'
                  : 'No token',
            ),
            _buildRow(
              'Token Length',
              '${fcmService.currentToken?.length ?? 0}',
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('Notification State', [
            _buildRow(
              'Total Notifications',
              '${notificationState.notifications.length}',
            ),
            _buildRow('Unread Count', '${notificationState.unreadCount}'),
            _buildRow('Has New', '${notificationState.hasNewNotification}'),
          ]),
          const SizedBox(height: 16),
          _buildActionButtons(ref, context),
          const SizedBox(height: 24),
          _buildRecentNotifications(notificationState),
          const SizedBox(height: 24),
          _buildTroubleshootingTips(fcmService, currentUser),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
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
            width: 150,
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

  Widget _buildActionButtons(WidgetRef ref, BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            // Force refresh FCM token
            final fcmService = ref.read(fcmServiceProvider);
            await fcmService.initialize();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('FCM reinitialized - check logs')),
              );
            }
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Reinitialize FCM'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            // Force token sync
            final fcmService = ref.read(fcmServiceProvider);
            fcmService.currentToken != null
                ? ref
                      .read(notificationNotifierProvider.notifier)
                      .setLoading(false)
                : null;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Token sync triggered')),
              );
            }
          },
          icon: const Icon(Icons.sync),
          label: const Text('Force Token Sync'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            // Add test notification
            ref.read(notificationNotifierProvider.notifier).addNotification({
              'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
              'title': '✅ TEST',
              'body': 'Test notification from debug screen',
              'type': 'manual_test',
              'donationId': null,
              'timestamp': DateTime.now().toIso8601String(),
              'isRead': false,
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Test notification added')),
              );
            }
          },
          icon: const Icon(Icons.bug_report),
          label: const Text('Add Test Notification'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            // Clear all notifications
            ref
                .read(notificationNotifierProvider.notifier)
                .setNotifications([]);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications cleared')),
              );
            }
          },
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear All Notifications'),
        ),
      ],
    );
  }

  Widget _buildRecentNotifications(dynamic state) {
    if (state.notifications.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No notifications yet'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Notifications (Last 5):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...state.notifications.take(5).map((notification) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${notification['title'] ?? 'No title'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${notification['body'] ?? 'No body'}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Type: ${notification['type'] ?? 'unknown'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootingTips(FcmService fcmService, dynamic user) {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔍 Troubleshooting Tips:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (fcmService.currentToken == null)
              _buildTip(
                '❌ No FCM token - Check if Firebase is configured correctly',
              ),
            if (fcmService.currentToken != null)
              _buildTip('✅ FCM token exists'),
            if (user == null)
              _buildTip(
                '❌ No user logged in - Login required for notifications',
              ),
            if (user != null) _buildTip('✅ User logged in'),
            _buildTip('Check Firebase Console > Functions logs'),
            _buildTip('Verify fcm_tokens field in Firestore users collection'),
            _buildTip('Ensure backend Cloud Function is deployed'),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('• $text'),
    );
  }
}
