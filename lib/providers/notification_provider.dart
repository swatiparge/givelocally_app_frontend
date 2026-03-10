// lib/providers/notification_provider.dart
// Riverpod State Management for Notifications with FCM

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/fcm_service.dart';

/// Provider for FcmService instance
final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService();
});

/// Provider for foreground message stream
/// Listen to this to show in-app notifications
final foregroundMessageProvider = StreamProvider<RemoteMessage>((ref) {
  final fcmService = ref.watch(fcmServiceProvider);
  return fcmService.foregroundMessageStream;
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

  /// Set notifications list
  void setNotifications(List<Map<String, dynamic>> notifications) {
    final unread = notifications.where((n) => !(n['isRead'] ?? true)).length;
    state = state.copyWith(
      notifications: notifications,
      unreadCount: unread,
      isLoading: false,
      hasNewNotification: false,
      error: null,
    );
  }

  /// Add a new notification (from FCM)
  void addNotification(Map<String, dynamic> notification) {
    final updated = [notification, ...state.notifications];
    state = state.copyWith(
      notifications: updated,
      unreadCount: state.unreadCount + 1,
      hasNewNotification: true,
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
