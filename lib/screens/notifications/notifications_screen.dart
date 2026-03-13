import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../providers/notification_provider.dart';
import '../../services/fcm_service.dart';
import '../../widgets/notification_tester.dart';
import '../chat/chat_screen.dart';
import '../home/donation_detail_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
      _clearNewNotificationFlag();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh notifications when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      debugPrint('NOTIFICATIONS_SCREEN: App resumed, refreshing...');
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    debugPrint("NOTIFICATIONS_SCREEN: Starting to load notifications...");
    final notifier = ref.read(notificationNotifierProvider.notifier);
    notifier.setLoading(true);

    try {
      final notifications = await _apiService.getNotifications();
      debugPrint(
        "NOTIFICATIONS_SCREEN: Got ${notifications.length} notifications from backend",
      );

      // Get current local notifications count
      final currentState = ref.read(notificationNotifierProvider);
      debugPrint(
        "NOTIFICATIONS_SCREEN: Current local notifications: ${currentState.notifications.length}",
      );

      // Debug: print first notification if exists
      if (notifications.isNotEmpty) {
        debugPrint(
          "NOTIFICATIONS_SCREEN: First backend notification: ${notifications.first}",
        );
      }

      if (mounted) {
        notifier.setNotifications(notifications.cast<Map<String, dynamic>>());

        // Check result
        final newState = ref.read(notificationNotifierProvider);
        debugPrint(
          "NOTIFICATIONS_SCREEN: After merge - total: ${newState.notifications.length}, unread: ${newState.unreadCount}",
        );
      }
    } catch (e, stackTrace) {
      debugPrint("NOTIFICATIONS_SCREEN: Error: $e");
      debugPrint("NOTIFICATIONS_SCREEN: StackTrace: $stackTrace");
      if (mounted) {
        notifier.setError(e.toString());
      }
    } finally {
      if (mounted) {
        notifier.setLoading(false);
      }
    }
  }

  void _clearNewNotificationFlag() {
    ref.read(notificationNotifierProvider.notifier).clearNewNotificationFlag();
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Debug button to force refresh
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              debugPrint('NOTIFICATIONS_SCREEN: Manual refresh triggered');
              _loadNotifications();
            },
            tooltip: 'Refresh notifications',
          ),
          if (notificationState.unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(notificationNotifierProvider.notifier).markAllAsRead();
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _buildBody(notificationState),
      ),
    );
  }

  Widget _buildBody(NotificationState state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "Error loading notifications",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.notifications.length,
      itemBuilder: (context, index) {
        final notification = state.notifications[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const NotificationTester(), // ADD THIS FOR TESTING
          const SizedBox(height: 24),
          const Icon(Icons.notifications_none, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "No notifications yet",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "We'll notify you when someone lists an item or sends a message.",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Show local FCM message status
          Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(notificationNotifierProvider);
              if (state.notifications.isNotEmpty) {
                return Container();
              }
              return const Text(
                "Note: Message notifications are captured locally.",
                style: TextStyle(color: Colors.orange, fontSize: 12),
                textAlign: TextAlign.center,
              );
            },
          ),
          const SizedBox(height: 24),
          // Debug: Show FCM token status
          Consumer(
            builder: (context, ref, child) {
              return Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadNotifications,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check for Notifications'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // Show FCM debug info
                      _showFcmDebugDialog();
                    },
                    child: const Text(
                      'Debug FCM Status',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFcmDebugDialog() {
    final fcmService = ref.read(fcmServiceProvider);
    final currentToken = fcmService.currentToken;
    final notificationState = ref.read(notificationNotifierProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FCM Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('FCM Available: ${fcmService.isAvailable}'),
              const SizedBox(height: 8),
              Text(
                'Token: ${currentToken != null ? "${currentToken.substring(0, currentToken.length > 20 ? 20 : currentToken.length)}..." : "Not set"}',
              ),
              const SizedBox(height: 16),
              Text(
                'Local notifications: ${notificationState.notifications.length}',
              ),
              const SizedBox(height: 8),
              if (notificationState.notifications.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...notificationState.notifications
                        .take(5)
                        .map(
                          (n) => Text(
                            '• ${n['type'] ?? 'unknown'}: ${n['title'] ?? 'no title'}',
                          ),
                        ),
                  ],
                ),
              const SizedBox(height: 16),
              const Text(
                'Check Firebase Console Functions Logs to see if notifications are being sent.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Common issues:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Backend Cloud Function not triggering'),
              const Text('• FCM token not saved to Firestore'),
              const Text('• User filtered out (self-notification)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Force reload
              _loadNotifications();
              Navigator.pop(context);
            },
            child: const Text('Refresh'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final String type = notification['type'] ?? 'info';
    final String body = notification['body'] ?? '';
    final String title = notification['title'] ?? '';
    final String receiverName = notification['receiverName'] ?? 'Someone';
    final String senderName =
        notification['senderName'] ?? notification['userName'] ?? 'Someone';
    final String time = _formatTime(notification['timestamp']);
    final bool isRead = notification['isRead'] ?? false;
    final String notificationId = notification['id'] ?? '';

    // Build display body based on notification type
    String displayBody = body;
    if (type == 'reservation') {
      // For reservation, show: "{ReceiverName} has reserved your {item}"
      displayBody = body
          .replaceAll('Someone', receiverName)
          .replaceAll('your item', 'your ${notification['title'] ?? 'item'}');
    } else {
      displayBody = body.replaceAll('Someone', senderName);
    }

    return InkWell(
      onTap: () {
        _handleNotificationTap(notification);
        if (!isRead && notificationId.isNotEmpty) {
          ref
              .read(notificationNotifierProvider.notifier)
              .markAsRead(notificationId);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : Colors.green.withOpacity(0.05),
          border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIconForType(type),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  if (title.isNotEmpty) const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                      children: _parseBody(displayBody),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final String? donationId = notification['donationId'];
    final String type = notification['type'] ?? '';

    debugPrint(
      "FCM: Tapped notification of type: $type, donationId: $donationId",
    );

    // Handle navigation based on notification type from backend
    switch (type) {
      case 'chat':
      case 'new_message':
      case 'message':
        if (donationId != null) {
          context.push(
            '/chat/$donationId',
            extra: {
              'donationId': donationId,
              'itemName':
                  notification['itemName'] ?? notification['title'] ?? 'Item',
              'itemImage': notification['itemImage'] ?? notification['image'],
              'requesterId':
                  notification['senderId'] ?? notification['requesterId'],
            },
          );
        }
        break;

      case 'nearby_donation':
      case 'donation_listed':
      case 'new_donation':
      case 'donation_reserved':
      case 'reservation':
      case 'acceptance':
      case 'payment':
      case 'pickup_code':
        if (donationId != null) {
          context.push(
            '/donation-detail',
            extra: {
              'id': donationId,
              'title': notification['title'] ?? 'Donation Details',
              ...notification,
            },
          );
        }
        break;

      case 'pickup_completed':
        if (donationId != null) {
          context.push(
            '/donation-detail',
            extra: {
              'id': donationId,
              'title': notification['title'] ?? 'Pickup Details',
              ...notification,
            },
          );
        }
        break;

      default:
        // Default to donation detail if donationId exists
        if (donationId != null) {
          context.push(
            '/donation-detail',
            extra: {
              'id': donationId,
              'title': notification['title'] ?? 'Details',
              ...notification,
            },
          );
        }
    }
  }

  List<TextSpan> _parseBody(String body) {
    final parts = body.split(' ');
    return parts.map((part) {
      final isImportant = part.startsWith('*') && part.endsWith('*');
      final text = isImportant ? part.replaceAll('*', '') : part;
      return TextSpan(
        text: "$text ",
        style: TextStyle(
          fontWeight: isImportant ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }).toList();
  }

  Widget _buildIconForType(String type) {
    IconData iconData;
    Color bgColor;
    Color iconColor;

    switch (type) {
      // Nearby donation - new type from backend
      case 'nearby_donation':
        iconData = Icons.location_on;
        bgColor = Colors.green[50]!;
        iconColor = Colors.green;
        break;

      // Reservation and acceptance
      case 'acceptance':
      case 'donation_reserved':
      case 'reservation':
        iconData = Icons.bookmark_added;
        bgColor = Colors.green[50]!;
        iconColor = Colors.green;
        break;

      // New donations
      case 'donation_listed':
      case 'new_donation':
        iconData = Icons.card_giftcard;
        bgColor = Colors.orange[50]!;
        iconColor = Colors.orange;
        break;

      // Payment related
      case 'payment':
        iconData = Icons.account_balance_wallet_outlined;
        bgColor = Colors.blue[50]!;
        iconColor = Colors.blue;
        break;

      // Pickup related
      case 'pickup_code':
      case 'pickup_completed':
        iconData = Icons.lock_outline;
        bgColor = Colors.amber[50]!;
        iconColor = Colors.amber;
        break;

      // Karma and rewards
      case 'karma':
        iconData = Icons.stars;
        bgColor = Colors.purple[50]!;
        iconColor = Colors.purple;
        break;

      // Chat and messages
      case 'chat':
      case 'new_message':
      case 'message':
        iconData = Icons.chat_bubble_outline;
        bgColor = Colors.teal[50]!;
        iconColor = Colors.teal;
        break;

      default:
        iconData = Icons.notifications_outlined;
        bgColor = Colors.grey[100]!;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime dt;
    if (timestamp is String) {
      dt = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else if (timestamp is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min${difference.inMinutes > 1 ? 's' : ''} ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago";
    } else if (difference.inDays == 1) {
      return "Yesterday, ${DateFormat.jm().format(dt)}";
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }
}
