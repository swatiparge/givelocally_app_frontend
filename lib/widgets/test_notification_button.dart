import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';

/// Test button to manually add a notification for debugging
class TestNotificationButton extends StatelessWidget {
  const TestNotificationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        final notifier = context is WidgetRef
            ? (context as WidgetRef).read(notificationNotifierProvider.notifier)
            : null;

        if (notifier != null) {
          // Add test notification
          notifier.addNotification({
            'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
            'title': 'Test Notification',
            'body': 'This is a test notification',
            'type': 'test',
            'donationId': 'test123',
            'timestamp': DateTime.now().toIso8601String(),
            'isRead': false,
          });

          ScaffoldMessenger.of(context as BuildContext).showSnackBar(
            const SnackBar(content: Text('Test notification added')),
          );
        }
      },
      icon: const Icon(Icons.bug_report),
      label: const Text('Add Test Notification'),
    );
  }
}
