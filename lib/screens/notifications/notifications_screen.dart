import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _apiService.getNotifications();
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _notificationsFuture = _apiService.getNotifications();
              });
              await _notificationsFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "No notifications yet",
            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            "We'll notify you when something important happens.",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(dynamic notification) {
    final String type = notification['type'] ?? 'info';
    final String title = notification['title'] ?? '';
    final String body = notification['body'] ?? '';
    final String time = _formatTime(notification['timestamp']);
    final bool isRead = notification['isRead'] ?? false;

    return Container(
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
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
                    children: _parseBody(body),
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
    );
  }

  List<TextSpan> _parseBody(String body) {
    // Basic bold parsing for words wrapped in stars or items
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
      default:
        iconData = Icons.chat_bubble_outline;
        bgColor = Colors.grey[100]!;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dt;
    if (timestamp is String) {
      dt = DateTime.parse(timestamp);
    } else if (timestamp is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes} mins ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} hours ago";
    } else if (difference.inDays == 1) {
      return "Yesterday, ${DateFormat.jm().format(dt)}";
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }
}
