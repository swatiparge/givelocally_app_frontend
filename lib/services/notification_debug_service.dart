import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for debugging and manually triggering notifications
/// This is for testing purposes only
class NotificationDebugService {
  static final NotificationDebugService _instance =
      NotificationDebugService._internal();
  factory NotificationDebugService() => _instance;
  NotificationDebugService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  /// Manually trigger a test notification
  /// This calls a Cloud Function to send a test notification to the current user
  Future<bool> sendTestNotification() async {
    try {
      debugPrint('NOTIFICATION_DEBUG: Sending test notification...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('NOTIFICATION_DEBUG: No user logged in');
        return false;
      }

      // Call the test notification Cloud Function
      // Note: This Cloud Function needs to be deployed on the backend
      final result = await _functions
          .httpsCallable('sendTestNotification')
          .call({
            'userId': user.uid,
            'title': 'Test Notification',
            'body': 'This is a test notification from GiveLocally!',
            'type': 'test',
          });

      debugPrint('NOTIFICATION_DEBUG: Test notification sent: ${result.data}');
      return result.data['success'] ?? false;
    } catch (e) {
      debugPrint('NOTIFICATION_DEBUG: Error sending test notification: $e');
      // Cloud Function might not exist - show helpful message
      if (e.toString().contains('not-found') ||
          e.toString().contains('does not exist')) {
        debugPrint(
          'NOTIFICATION_DEBUG: The sendTestNotification Cloud Function is not deployed.',
        );
        debugPrint(
          'NOTIFICATION_DEBUG: Please deploy the Cloud Function from the backend repository.',
        );
      }
      return false;
    }
  }

  /// Check if notification Cloud Functions are available
  Future<Map<String, dynamic>> checkBackendStatus() async {
    final status = <String, dynamic>{
      'sendTestNotification': false,
      'getNotifications': false,
      'createdonation': false,
    };

    try {
      // Try to call getNotifications (this should exist)
      final result = await _functions
          .httpsCallable('getNotifications')
          .call({});
      status['getNotifications'] = result.data != null;
    } catch (e) {
      debugPrint('NOTIFICATION_DEBUG: getNotifications check failed: $e');
    }

    // Note: We can't easily check if createdonation exists without actually creating a donation
    // But we can infer from the fact that donations can be created

    return status;
  }

  /// Get FCM token status for debugging
  Future<Map<String, dynamic>> getFcmStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'error': 'No user logged in'};
      }

      // Get user document to check if FCM token is stored
      final userDoc = await _functions.httpsCallable('getUserProfile').call({
        'userId': user.uid,
      });

      return {
        'userId': user.uid,
        'fcmTokens': userDoc.data['fcm_tokens'] ?? [],
        'hasToken': (userDoc.data['fcm_tokens'] ?? []).isNotEmpty,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
