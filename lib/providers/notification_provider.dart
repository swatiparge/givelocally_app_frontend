// lib/providers/notification_provider.dart
// Riverpod State Management for Notifications with FCM

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/fcm_service.dart';

/// Provider for FcmService instance
final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService();
});

/// Notification state model
class NotificationState {
  final List<Map<String, dynamic>> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;
  final bool hasNewNotification;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
    this.hasNewNotification = false,
  });

  NotificationState copyWith({
    List<Map<String, dynamic>>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
    bool? hasNewNotification,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
      hasNewNotification: hasNewNotification ?? this.hasNewNotification,
    );
  }
}

/// Notification notifier for managing notification state
class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(const NotificationState());

  /// Set loading state
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// Set notifications list - MERGES with existing FCM notifications
  void setNotifications(List<Map<String, dynamic>> backendNotifications) {
    // Merge backend notifications with existing ones
    // Backend notifications take precedence for existing entries
    final mergedNotifications = <Map<String, dynamic>>[];
    final processedIds = <String>{};

    // First, add backend notifications
    for (final notification in backendNotifications) {
      final id = notification['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        mergedNotifications.add(notification);
        processedIds.add(id);
      }
    }

    // Then, add local FCM notifications that aren't in backend
    for (final notification in state.notifications) {
      final id = notification['id']?.toString() ?? '';
      if (id.isNotEmpty && !processedIds.contains(id)) {
        mergedNotifications.add(notification);
      }
    }

    // Sort by timestamp (newest first)
    mergedNotifications.sort((a, b) {
      final aTime = _parseTimestamp(a['timestamp']);
      final bTime = _parseTimestamp(b['timestamp']);
      return bTime.compareTo(aTime);
    });

    final unread = mergedNotifications
        .where((n) => !(n['isRead'] ?? true))
        .length;
    state = state.copyWith(
      notifications: mergedNotifications,
      unreadCount: unread,
      isLoading: false,
      error: null,
    );
  }

  /// Helper to parse various timestamp formats
  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime(1970);
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime(1970);
    }
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return DateTime(1970);
  }

  /// Add a new notification (from FCM) - PREVENTS DUPLICATES
  void addNotification(Map<String, dynamic> notification) {
    final notificationId = notification['id']?.toString() ?? '';
    final senderId =
        notification['senderId']?.toString() ??
        notification['userId']?.toString() ??
        '';

    // Skip if this is the current user's own message
    // We'll check this in the FCM service before calling addNotification

    // Check for duplicates by ID
    if (notificationId.isNotEmpty) {
      final exists = state.notifications.any(
        (n) => n['id']?.toString() == notificationId,
      );
      if (exists) {
        debugPrint(
          'NOTIFICATION_PROVIDER: Skipping duplicate notification: $notificationId',
        );
        return;
      }
    }

    // Also check for duplicates by content (same sender + same message + within 5 seconds)
    final messageBody = notification['body']?.toString() ?? '';
    final now = DateTime.now();
    final isDuplicate = state.notifications.any((n) {
      final existingBody = n['body']?.toString() ?? '';
      final existingSender =
          n['senderId']?.toString() ?? n['userId']?.toString() ?? '';
      final existingTime = _parseTimestamp(n['timestamp']);
      final timeDiff = now.difference(existingTime).inSeconds.abs();

      return existingBody == messageBody &&
          existingSender == senderId &&
          timeDiff < 5; // Within 5 seconds
    });

    if (isDuplicate) {
      debugPrint('NOTIFICATION_PROVIDER: Skipping duplicate by content');
      return;
    }

    final updated = [notification, ...state.notifications];
    state = state.copyWith(
      notifications: updated,
      unreadCount: state.unreadCount + 1,
      hasNewNotification: true,
    );
    debugPrint(
      'NOTIFICATION_PROVIDER: Added notification: ${notification['id']}',
    );
  }

  /// Mark notification as read
  void markAsRead(String notificationId) {
    final updated = state.notifications.map((n) {
      if (n['id'] == notificationId) {
        return {...n, 'isRead': true};
      }
      return n;
    }).toList();

    final unread = updated.where((n) => !(n['isRead'] ?? true)).length;
    state = state.copyWith(notifications: updated, unreadCount: unread);
  }

  /// Mark all as read
  void markAllAsRead() {
    final updated = state.notifications.map((n) {
      return {...n, 'isRead': true};
    }).toList();

    state = state.copyWith(
      notifications: updated,
      unreadCount: 0,
      hasNewNotification: false,
    );
  }

  /// Set error
  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  /// Clear new notification flag
  void clearNewNotificationFlag() {
    state = state.copyWith(hasNewNotification: false);
  }
}

/// Provider for notification notifier
final notificationNotifierProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
      return NotificationNotifier();
    });

/// Provider for unread notification count
final unreadCountProvider = Provider<int>((ref) {
  final state = ref.watch(notificationNotifierProvider);
  return state.unreadCount;
});

/// Provider for notifications list
final notificationsListProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final state = ref.watch(notificationNotifierProvider);
  return state.notifications;
});

/// Provider for notification loading state
final notificationsLoadingProvider = Provider<bool>((ref) {
  final state = ref.watch(notificationNotifierProvider);
  return state.isLoading;
});

/// Provider to check if there are new notifications
final hasNewNotificationProvider = Provider<bool>((ref) {
  final state = ref.watch(notificationNotifierProvider);
  return state.hasNewNotification;
});
