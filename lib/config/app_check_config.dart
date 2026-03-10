import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// App Check Configuration
///
/// Debug: Uses debug token (for development)
/// Production: Uses Play Integrity (for Play Store)
class AppCheckConfig {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    try {
      if (kDebugMode) {
        // Development: Use debug provider with short timeout
        await FirebaseAppCheck.instance
            .activate(androidProvider: AndroidProvider.debug)
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                debugPrint('⚠️ App Check: Activation timed out');
                throw TimeoutException('App Check activation timeout');
              },
            );

        // Try to get token but don't block on failure
        try {
          final token = await FirebaseAppCheck.instance.getToken().timeout(
            const Duration(seconds: 3),
          );
          debugPrint('🔥 App Check Debug Token: $token');
        } catch (e) {
          debugPrint('⚠️ App Check: Could not get token: $e');
        }
      } else {
        // Production/Internal Testing: Use Play Integrity with timeout
        await FirebaseAppCheck.instance
            .activate(
              androidProvider: AndroidProvider.playIntegrity,
              // appleProvider: AppleProvider.deviceCheck, // For iOS
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('⚠️ App Check: Activation timed out');
                throw TimeoutException('App Check activation timeout');
              },
            );
      }

      _isInitialized = true;
      debugPrint('✅ App Check: Initialized successfully');
    } catch (e) {
      _isInitialized = false;
      debugPrint('⚠️ App Check: Initialization failed: $e');
      // Don't throw - app should work without App Check
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => 'TimeoutException: $message';
}
