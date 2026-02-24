library razorpay_auth_capture;

import 'dart:async';
import 'package:flutter/material.dart';

// Import local files
import 'models/payment_models.dart';
import 'screens/payment_prompt_screen.dart';
import 'screens/pickup_code_screen.dart';
import 'screens/verify_pickup_code_screen.dart';
import 'src/payment_service.dart';

// Export models
export 'models/payment_models.dart';

// Export screens
export 'screens/payment_prompt_screen.dart';
export 'screens/pickup_code_screen.dart';
export 'screens/verify_pickup_code_screen.dart';
export 'screens/verification_success_screen.dart';
export 'screens/verification_expired_screen.dart';

// Export services
export 'src/payment_service.dart';

// Main plugin class
class RazorpayAuthCapture {
  static final RazorpayAuthCapture _instance = RazorpayAuthCapture._internal();
  factory RazorpayAuthCapture() => _instance;
  RazorpayAuthCapture._internal();

  RazorpayConfig? _config;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize(RazorpayConfig config) async {
    if (!config.isValid) {
      throw ArgumentError('Invalid Razorpay configuration');
    }
    _config = config;
    _initialized = true;
    debugPrint('✅ RazorpayAuthCapture initialized');
  }

  RazorpayConfig get config {
    if (_config == null) {
      throw StateError('RazorpayAuthCapture not initialized');
    }
    return _config!;
  }

  PaymentService createPaymentService() {
    if (!_initialized) {
      throw StateError('RazorpayAuthCapture not initialized');
    }
    return PaymentService(config);
  }

  static Future<dynamic> showPaymentPrompt({
    required BuildContext context,
    required String donationId,
    required String donorName,
    required String itemTitle,
    required String userPhone,
    required String userEmail,
    VoidCallback? onSuccess,
    VoidCallback? onCancel,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPromptScreen(
          donationId: donationId,
          donorName: donorName,
          itemTitle: itemTitle,
          userPhone: userPhone,
          userEmail: userEmail,
          onSuccess: onSuccess,
          onCancel: onCancel,
        ),
      ),
    );
  }

  static Future<dynamic> showPickupCode({
    required BuildContext context,
    required Map<String, dynamic> transaction,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PickupCodeScreen(
          transaction: transaction,
        ),
      ),
    );
  }

  static Future<dynamic> showVerifyPickup({
    required BuildContext context,
    required String donationId,
    required String receiverName,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerifyPickupCodeScreen(
          donationId: donationId,
          receiverName: receiverName,
        ),
      ),
    );
  }
}
