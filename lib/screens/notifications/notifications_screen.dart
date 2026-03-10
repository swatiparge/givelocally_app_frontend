import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../providers/notification_provider.dart';
import '../../routes/app_router.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
      _clearNewNotificationFlag();
    });
  }

  Future<void> _loadNotifications() async {
    debugPrint("NOTIFICATIONS_SCREEN: Starting to load notifications...");
    final notifier = ref.read(notificationNotifierProvider.notifier);
    notifier.setLoading(true);

    // Safety timeout - ensure loading stops after 15 seconds max
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        final state = ref.read(notificationNotifierProvider);
        if (state.isLoading) {
          notifier.setLoading(false);
          debugPrint("NOTIFICATIONS_SCREEN: Safety timeout stopped loading");
        }
      }
    });

    try {
      final notifications = await _apiService.getNotifications();
      debugPrint(
        "NOTIFICATIONS_SCREEN: Got ${notifications.length} notifications",
      );
      if (mounted) {
        notifier.setNotifications(notifications.cast<Map<String, dynamic>>());
        debugPrint("NOTIFICATIONS_SCREEN: State updated");
      }
    } catch (e) {
      debugPrint("NOTIFICATIONS_SCREEN: Error: $e");
      if (mounted) {
        notifier.setError(e.toString());
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No notifications yet",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "We'll notify you when something important happens.",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final String type = notification['type'] ?? 'info';
    final String body = notification['body'] ?? '';
    final String title = notification['title'] ?? '';
    final String userName =
        notification['userName'] ?? notification['donorName'] ?? 'Someone';
    final String time = _formatTime(notification['timestamp']);
    final bool isRead = notification['isRead'] ?? false;
    final String? donationId = notification['donationId'];
    final String? chatId = notification['chatId'];
    final String notificationId = notification['id'] ?? '';

    String displayBody = body
        .replaceAll('Priya', userName)
        .replaceAll('Someone', userName);

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
    final String? chatId = notification['chatId'];
    final String type = notification['type'] ?? '';

    if (donationId != null) {
      // Navigate to donation detail
      // context.push(AppRouter.donationDetail, extra: {'id': donationId});
    } else if (chatId != null) {
      // Navigate to chat
      // context.push(AppRouter.chat, extra: {'chatId': chatId});
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notification tapped: $type'),
        duration: const Duration(seconds: 2),
      ),
    );
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
      case 'acceptance':
        iconData = Icons.person_add_alt_1;
        bgColor = Colors.green[50]!;
        iconColor = Colors.green;
        break;
      case 'payment':
        iconData = Icons.account_balance_wallet_outlined;
        bgColor = Colors.orange[50]!;
        iconColor = Colors.orange;
        break;
      case 'pickup_code':
        iconData = Icons.lock_outline;
        bgColor = Colors.blue[50]!;
        iconColor = Colors.blue;
        break;
      case 'karma':
        iconData = Icons.stars;
        bgColor = Colors.purple[50]!;
        iconColor = Colors.purple;
        break;
      case 'chat':
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
