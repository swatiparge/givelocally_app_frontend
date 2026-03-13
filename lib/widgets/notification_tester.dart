import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';

/// Simple widget to test if notification provider is working
class NotificationTester extends StatelessWidget {
  const NotificationTester({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '🧪 Notification Test',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Try to add a test notification
                    ref
                        .read(notificationNotifierProvider.notifier)
                        .addNotification({
                          'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
                          'title': '✅ TEST NOTIFICATION',
                          'body': 'If you see this, the provider is working!',
                          'type': 'manual_test',
                          'donationId': null,
                          'timestamp': DateTime.now().toIso8601String(),
                          'isRead': false,
                        });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Test notification added! Check the list.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Add Test Notification'),
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final state = ref.watch(notificationNotifierProvider);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current notifications: ${state.notifications.length}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '💡 Tip: If test works but real notifications don\'t appear,',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                        const Text(
                          'check Firebase Console → Functions logs',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
