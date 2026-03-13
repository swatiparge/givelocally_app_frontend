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
        // Development: Use debug provider with longer timeout for first-time handshake
        await FirebaseAppCheck.instance
            .activate(androidProvider: AndroidProvider.debug)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                debugPrint('⚠️ App Check: Activation timed out');
                throw TimeoutException('App Check activation timeout');
              },
            );

        // Try to get token to verify initialization
        try {
          final token = await FirebaseAppCheck.instance.getToken().timeout(
            const Duration(seconds: 15),
          );
          if (token != null && token.contains('error')) {
             debugPrint('❌ App Check: Received error response. Check google-services.json and Play Services.');
          }
          debugPrint('🔥 App Check Debug Token: $token');
        } catch (e) {
          debugPrint('⚠️ App Check: Could not get token: $e');
        }
      } else {
        // Production/Internal Testing: Use Play Integrity
        await FirebaseAppCheck.instance
            .activate(
              androidProvider: AndroidProvider.playIntegrity,
            )
            .timeout(
              const Duration(seconds: 10),
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
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => 'TimeoutException: $message';
}
