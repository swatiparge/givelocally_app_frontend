part of '../razorpay_auth_capture.dart';

/// Main plugin class for Razorpay Auth Capture
class RazorpayAuthCapture {
  static final RazorpayAuthCapture _instance = RazorpayAuthCapture._internal();
  factory RazorpayAuthCapture() => _instance;
  RazorpayAuthCapture._internal();

  RazorpayConfig? _config;
  bool _initialized = false;

  /// Check if plugin is initialized
  bool get isInitialized => _initialized;

  /// Initialize the plugin with configuration
  Future<void> initialize(RazorpayConfig config) async {
    if (!config.isValid) {
      throw ArgumentError('Invalid Razorpay configuration');
    }

    _config = config;
    _initialized = true;

    // Initialize Firebase if not already done
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    debugPrint('✅ RazorpayAuthCapture initialized');
  }

  /// Get current configuration
  RazorpayConfig get config {
    if (_config == null) {
      throw StateError(
          'RazorpayAuthCapture not initialized. Call initialize() first.');
    }
    return _config!;
  }

  /// Create a payment service instance
  PaymentService createPaymentService() {
    if (!_initialized) {
      throw StateError(
          'RazorpayAuthCapture not initialized. Call initialize() first.');
    }
    return PaymentService(config);
  }

  /// Navigate to payment prompt screen
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

  /// Navigate to pickup code screen
  static Future<dynamic> showPickupCode({
    required BuildContext context,
    required String transactionId,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PickupCodeScreen(
          transactionId: transactionId,
        ),
      ),
    );
  }

  /// Navigate to verify pickup screen (for donor)
  static Future<dynamic> showVerifyPickup({
    required BuildContext context,
    required String donationId,
    required String receiverName,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerifyPickupScreen(
          donationId: donationId,
          receiverName: receiverName,
        ),
      ),
    );
  }
}
