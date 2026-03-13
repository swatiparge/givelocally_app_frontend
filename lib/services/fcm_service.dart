import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notification_provider.dart';
import '../routes/app_router.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM: Background message received: ${message.messageId}');
  debugPrint('FCM: Notification: ${message.notification?.title}');
  debugPrint('FCM: Data: ${message.data}');

  // Show local notification for background messages
  await FlutterLocalNotificationsPlugin().show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000).toInt(),
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? '',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel', // ✅ Fixed: Match AndroidManifest.xml
        'GiveLocally Notifications',
        channelDescription: 'Notifications for GiveLocally app',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: message.data.toString(),
  );
}

/// FCM Service for managing Firebase Cloud Messaging
class FcmService {
  // Singleton pattern
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Global key to show snackbars when app is in foreground
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  String? _currentToken;
  String? get currentToken => _currentToken;

  bool _isAvailable = true;
  bool get isAvailable => _isAvailable;

  Future<void> initialize() async {
    debugPrint('FCM: Initializing...');

    try {
      // 1. Initialize local notifications
      await _initializeLocalNotifications();

      // 2. Setup background message handler FIRST
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // 3. Setup listeners BEFORE anything else
      _messaging.onTokenRefresh.listen(_onTokenRefresh);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 4. Request permissions EARLY
      await _requestPermissions();

      // 5. Get token IMMEDIATELY after permissions
      await _syncTokenWithRetry();

      // 6. Auth State Listener
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          debugPrint(
            'FCM: User authenticated (${user.uid}), triggering sync...',
          );
          _syncToken();
        }
      });

      // 7. Check if app was opened from a notification
      await _checkInitialMessage();

      debugPrint('FCM: Initialization complete');
    } catch (e) {
      debugPrint('⚠️ FCM: Initialization failed (non-fatal): $e');
      _isAvailable = false;
    }
  }

  /// Initialize local notifications for foreground alerts
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tapped: ${response.payload}');
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            _handleNotificationNavigation(data);
          } catch (e) {
            debugPrint('FCM: Error parsing notification payload: $e');
          }
        }
      },
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel', // ✅ Fixed: Match AndroidManifest.xml
        'GiveLocally Notifications',
        description: 'Notifications for GiveLocally app',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(androidChannel);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM: Permission status: ${settings.authorizationStatus}');

      // Request local notification permissions
      if (Platform.isAndroid) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FCM: Permissions authorized, syncing token...');
        await _syncToken();
      }
    } catch (e) {
      debugPrint('⚠️ FCM: Error requesting permissions: $e');
    }
  }

  Future<void> _syncTokenWithRetry() async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        final success = await _syncToken();
        if (success) {
          _isAvailable = true;
          return;
        }
        attempts++;
        debugPrint('⚠️ FCM: Token sync attempt $attempts returned no token');
      } catch (e) {
        attempts++;
        debugPrint(
          '⚠️ FCM: Token sync attempt $attempts failed with error: $e',
        );
      }

      if (attempts < maxAttempts) {
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
    _isAvailable = false;
  }

  Future<bool> _syncToken() async {
    try {
      _currentToken = await _messaging.getToken();

      if (_currentToken != null && _currentToken!.isNotEmpty) {
        final displayToken = _currentToken!.length > 15
            ? '${_currentToken!.substring(0, 15)}...'
            : _currentToken;
        debugPrint('FCM: Token retrieved: $displayToken');

        await _sendTokenToServer(_currentToken!);
        return true;
      }

      debugPrint('⚠️ FCM: Token retrieved is null or empty');
      return false;
    } catch (e) {
      debugPrint('⚠️ FCM: Error getting token: $e');
      return false;
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    debugPrint('FCM: Token refreshed by system');
    _currentToken = token;
    if (token.isNotEmpty) {
      await _sendTokenToServer(token);
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    if (token.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint(
        'FCM: No user logged in, token saved locally but not synced to Firestore',
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcm_tokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'fcmPlatform': Platform.operatingSystem,
        'fcm_token_debug': token,
      }, SetOptions(merge: true));

      debugPrint(
        '✅ FCM: Token successfully pushed to Firestore for user ${user.uid}',
      );
    } catch (e) {
      debugPrint('⚠️ FCM: Firestore token sync failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 FCM: Foreground message received: ${message.messageId}');
    debugPrint('📩 FCM: Data: ${message.data}');
    debugPrint(
      '📩 FCM: Notification: ${message.notification?.title} - ${message.notification?.body}',
    );

    // 1. Add to provider (for in-app notification list)
    _addNotificationToProvider(message);

    // 2. Show system notification (even when app is in foreground)
    _showSystemNotification(message);

    // ✅ Removed: Stream controller to prevent duplicate processing
    // Notification is now handled only via _addNotificationToProvider
  }

  /// Show system-level notification when app is in foreground
  Future<void> _showSystemNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'New Notification';
    final body = message.notification?.body ?? '';
    final data = message.data;

    debugPrint('🔔 Showing system notification: $title - $body');

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // ✅ Fixed: Match AndroidManifest.xml
      'GiveLocally Notifications',
      channelDescription: 'Notifications for GiveLocally app',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000).toInt(),
      title,
      body,
      details,
      payload: data.toString(),
    );
  }

  void _addNotificationToProvider(RemoteMessage message) {
    debugPrint('🔍 === NOTIFICATION RECEIVED ===');
    debugPrint('Message ID: ${message.messageId}');
    debugPrint('Notification Title: ${message.notification?.title}');
    debugPrint('Notification Body: ${message.notification?.body}');
    debugPrint('Data Keys: ${message.data.keys.toList()}');
    debugPrint('Data Values: ${message.data}');

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ FCM: No current user, skipping notification');
        return;
      }

      final notificationType = message.data['type']?.toString() ?? '';
      final senderId =
          message.data['senderId']?.toString() ??
          message.data['userId']?.toString() ??
          '';
      final donorId = message.data['donorId']?.toString() ?? '';
      final receiverId = message.data['receiverId']?.toString() ?? '';

      debugPrint('📩 FCM: Processing notification');
      debugPrint(' Type: $notificationType');
      debugPrint(' Sender: ${senderId.isEmpty ? "NOT PROVIDED" : senderId}');
      debugPrint(' Donor: ${donorId.isEmpty ? "NOT PROVIDED" : donorId}');
      debugPrint(
        ' Receiver: ${receiverId.isEmpty ? "NOT PROVIDED" : receiverId}',
      );
      debugPrint(' Current User: ${currentUser.uid}');

      // Filter: Skip self chat messages
      if (notificationType == 'chat' ||
          notificationType == 'message' ||
          notificationType == 'new_message') {
        if (senderId.isNotEmpty && senderId == currentUser.uid) {
          debugPrint('FCM: Skipping self chat message');
          return;
        }
      }

      // Filter: Skip reservation if I'm the receiver
      if (notificationType == 'reservation') {
        if (receiverId.isNotEmpty && receiverId == currentUser.uid) {
          debugPrint(
            'FCM: Skipping reservation notification (I am the receiver)',
          );
          return;
        }
      }

      // Filter: Skip nearby donation if I'm the donor
      if (notificationType == 'nearby_donation') {
        if (donorId.isNotEmpty && donorId == currentUser.uid) {
          debugPrint('FCM: Skipping nearby donation (own donation)');
          return;
        }
      }

      debugPrint('✅ FCM: Letting notification through');

      final notificationData = {
        'id':
            message.messageId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'title':
            message.notification?.title ??
            message.data['title'] ??
            'New Notification',
        'body': message.notification?.body ?? message.data['body'] ?? '',
        'type': notificationType,
        'donationId': message.data['donationId'],
        'senderId': senderId,
        'donorId': donorId,
        'receiverId': receiverId,
        'userName':
            message.data['userName'] ??
            message.data['senderName'] ??
            message.data['donorName'],
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
        ...message.data,
      };

      debugPrint(
        'FCM: Adding notification - id: ${notificationData['id']}, type: ${notificationData['type']}, title: ${notificationData['title']}',
      );

      _addToQueue(notificationData);
      _processNotificationQueue();

      debugPrint('FCM: ✅ Notification queued and processed');
    } catch (e, stackTrace) {
      debugPrint('FCM: Error adding notification to provider: $e');
      debugPrint('FCM: Stack trace: $stackTrace');
    }
  }

  // Queue for notifications when provider is not yet available
  static final List<Map<String, dynamic>> _notificationQueue = [];
  static const int _maxQueueSize = 100; // Prevent memory leak
  static WeakReference<WidgetRef>? _globalRef;

  static void setGlobalRef(WidgetRef ref) {
    _globalRef = WeakReference(ref);
    _processNotificationQueue();
  }

  static void clearGlobalRef() {
    _globalRef = null;
    debugPrint('FCM: Global ref cleared');
  }

  static void _addToQueue(Map<String, dynamic> notification) {
    // Prevent queue from growing indefinitely
    if (_notificationQueue.length >= _maxQueueSize) {
      _notificationQueue.removeAt(0); // FIFO eviction
    }
    _notificationQueue.add(notification);
  }

  static void _processNotificationQueue() {
    final ref = _globalRef?.target;
    if (ref == null) {
      debugPrint('FCM: _globalRef is null or invalid, cannot process yet');
      return;
    }

    debugPrint(
      'FCM: Processing ${_notificationQueue.length} queued notifications',
    );

    while (_notificationQueue.isNotEmpty) {
      final notification = _notificationQueue.removeAt(0);
      try {
        debugPrint(
          'FCM: Adding notification ${notification['id']} to provider',
        );
        ref
            .read(notificationNotifierProvider.notifier)
            .addNotification(notification);
        debugPrint('FCM: ✅ Successfully added notification');
      } catch (e) {
        debugPrint('FCM: ❌ Error processing notification: $e');
      }
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('FCM: Notification tapped (background)');
    _handleNotificationNavigation(message.data);
  }

  Future<void> _checkInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      // ✅ FIX: Queue initial message instead of processing immediately
      // Navigation will happen after widget tree is built
      _pendingInitialMessage = message;
      debugPrint('FCM: Initial message queued for later navigation');
    }
  }

  // Store pending initial message for navigation after widget tree is ready
  static RemoteMessage? _pendingInitialMessage;

  /// Process pending initial message - call this after widget tree is built
  void processPendingInitialMessage() {
    if (_pendingInitialMessage != null) {
      debugPrint('FCM: Processing pending initial message');
      _handleNotificationNavigation(_pendingInitialMessage!.data);
      _pendingInitialMessage = null;
    }
  }

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    debugPrint('FCM: Handling navigation for data: $data');

    final String? donationId = data['donationId'];
    final String type = data['type'] ?? '';

    if (donationId == null) return;

    final BuildContext? context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('FCM: No context available for navigation');
      return;
    }

    final router = GoRouter.of(context);

    switch (type) {
      case 'chat':
      case 'message':
        router.push(
          '/chat/$donationId',
          extra: {
            'donationId': donationId,
            'itemName': data['itemName'] ?? 'Item',
            'itemImage': data['itemImage'],
          },
        );
        break;
      case 'donation_listed':
      case 'donation_reserved':
      case 'reservation':
      case 'acceptance':
      case 'payment':
      case 'pickup_code':
        router.push(
          '/donation-detail',
          extra: {
            'id': donationId,
            'title': data['title'] ?? 'Donation Details',
            ...data,
          },
        );
        break;
      default:
        router.push(
          '/donation-detail',
          extra: {
            'id': donationId,
            'title': data['title'] ?? 'Donation Details',
            ...data,
          },
        );
    }
  }

  Future<void> deleteToken() async {
    if (!_isAvailable) return;
    try {
      await _messaging.deleteToken();
      _currentToken = null;
      debugPrint('FCM: Token deleted');
    } catch (e) {
      debugPrint('⚠️ FCM: Error deleting token: $e');
    }
  }

  void dispose() {
    // Stream controller removed - no cleanup needed
    debugPrint('FCM: Service disposed');
  }
}
