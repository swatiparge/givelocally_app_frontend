import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM: Background message received: ${message.messageId}');
  debugPrint('FCM: Notification: ${message.notification?.title}');
  debugPrint('FCM: Data: ${message.data}');
  // Background messages are handled by the system - no UI updates here
}

/// FCM Service for managing Firebase Cloud Messaging
///
/// Handles:
/// - Token generation and management
/// - Foreground/background message handling
/// - Token refresh and server sync
/// - Notification permissions
class FcmService {
  // Singleton pattern
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  // Stream controller for foreground messages
  final _foregroundMessageController =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get foregroundMessageStream =>
      _foregroundMessageController.stream;

  // Current FCM token
  String? _currentToken;
  String? get currentToken => _currentToken;

  // Track if FCM is available (Installations service working)
  bool _isAvailable = true;
  bool get isAvailable => _isAvailable;

  /// Initialize FCM service
  /// Call this in main.dart after Firebase.initializeApp()
  Future<void> initialize() async {
    debugPrint('FCM: Initializing...');

    try {
      // Set background handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Request permissions (iOS only, Android auto-granted)
      await _requestPermissions();

      // Get and sync initial token (with retry)
      await _syncTokenWithRetry();

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen(_onTokenRefresh);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification (terminated state)
      await _checkInitialMessage();

      debugPrint('FCM: Initialization complete');
    } catch (e) {
      debugPrint('⚠️ FCM: Initialization failed (non-fatal): $e');
      _isAvailable = false;
      // Don't throw - app should work without FCM
    }
  }

  /// Request notification permissions (iOS)
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('FCM: iOS permission status: ${settings.authorizationStatus}');
    } else {
      // Android: Check if notifications are enabled
      final settings = await _messaging.getNotificationSettings();
      debugPrint(
        'FCM: Android notification settings: ${settings.authorizationStatus}',
      );
    }
  }

  /// Get current FCM token and sync with server (with retry)
  Future<void> _syncTokenWithRetry() async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        await _syncToken();
        _isAvailable = true;
        return;
      } catch (e) {
        attempts++;
        debugPrint(
          '⚠️ FCM: Token sync attempt $attempts/$maxAttempts failed: $e',
        );

        if (attempts >= maxAttempts) {
          debugPrint(
            '⚠️ FCM: All token sync attempts failed. Notifications may not work.',
          );
          _isAvailable = false;
          // Don't throw - continue without FCM
          return;
        }

        // Wait before retry
        await Future.delayed(Duration(seconds: attempts));
      }
    }
  }

  /// Get current FCM token and sync with server
  Future<void> _syncToken() async {
    try {
      _currentToken = await _messaging.getToken();
      debugPrint('FCM: Token retrieved: ${_currentToken?.substring(0, 20)}...');

      if (_currentToken != null) {
        await _sendTokenToServer(_currentToken!);
      }
    } catch (e) {
      debugPrint('⚠️ FCM: Error getting token: $e');
      rethrow;
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String token) async {
    debugPrint('FCM: Token refreshed: ${token.substring(0, 20)}...');
    _currentToken = token;
    try {
      await _sendTokenToServer(token);
    } catch (e) {
      debugPrint('⚠️ FCM: Failed to sync refreshed token: $e');
    }
  }

  /// Send FCM token to backend server
  Future<void> _sendTokenToServer(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('FCM: No user logged in, skipping token sync');
        return;
      }

      final callable = _functions.httpsCallable('updateFcmToken');
      await callable.call({
        'token': token,
        'platform': Platform.operatingSystem,
        'userId': user.uid,
      });
      debugPrint('FCM: Token synced to server');
    } catch (e) {
      debugPrint('⚠️ FCM: Error syncing token: $e');
      // Don't throw - token sync is not critical
    }
  }

  /// Handle foreground messages (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM: Foreground message received');
    debugPrint('FCM: Title: ${message.notification?.title}');
    debugPrint('FCM: Body: ${message.notification?.body}');
    debugPrint('FCM: Data: ${message.data}');

    // Broadcast to listeners (e.g., notification screen)
    _foregroundMessageController.add(message);
  }

  /// Handle notification tap when app is in background
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('FCM: Notification tapped (background)');
    debugPrint('FCM: Data: ${message.data}');

    // Handle navigation based on notification type
    _handleNotificationNavigation(message.data);
  }

  /// Check if app was opened from a notification (terminated state)
  Future<void> _checkInitialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      if (message != null) {
        debugPrint('FCM: App opened from notification');
        debugPrint('FCM: Data: ${message.data}');
        _handleNotificationNavigation(message.data);
      }
    } catch (e) {
      debugPrint('⚠️ FCM: Error checking initial message: $e');
    }
  }

  /// Handle navigation based on notification data
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final donationId = data['donationId'] as String?;
    final chatId = data['chatId'] as String?;

    debugPrint(
      'FCM: Navigation - type=$type, donationId=$donationId, chatId=$chatId',
    );

    // Store navigation data for router to handle
    // The actual navigation happens in the widget that listens to this
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    if (!_isAvailable) {
      debugPrint('⚠️ FCM: Service unavailable, cannot subscribe to topic');
      return;
    }
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('FCM: Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('⚠️ FCM: Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isAvailable) {
      debugPrint('⚠️ FCM: Service unavailable, cannot unsubscribe from topic');
      return;
    }
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('FCM: Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('⚠️ FCM: Error unsubscribing from topic: $e');
    }
  }

  /// Delete FCM token (logout)
  Future<void> deleteToken() async {
    if (!_isAvailable) {
      debugPrint('⚠️ FCM: Service unavailable, cannot delete token');
      return;
    }
    try {
      await _messaging.deleteToken();
      _currentToken = null;
      debugPrint('FCM: Token deleted');
    } catch (e) {
      debugPrint('⚠️ FCM: Error deleting token: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _foregroundMessageController.close();
  }
}
