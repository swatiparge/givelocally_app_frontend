import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';

// Conditional import for web - use prefix to avoid name conflicts
import 'payment_service_web.dart'
    if (dart.library.io) 'payment_service_mobile.dart' as razorpay_web;

/// Payment Service for handling Razorpay Promise Fee Flow
/// Handles Authorization (Hold) -> Void (Refund) or Capture (Forfeit)
class PaymentService {
  Razorpay? _razorpay;

  // Track if we're on web platform
  final bool _isWeb = kIsWeb;

  // Load from .env file
  String get _razorpayKeyId => dotenv.env['RAZORPAY_KEY_ID'] ?? '';

  // Cloud Function Region
  static const String _functionsRegion = 'asia-southeast1';

  Function(String)? _onSuccessCallback;
  Function(String)? _onErrorCallback;

  /// Initialize Razorpay event listeners
  void init() {
    if (!_isWeb) {
      // Mobile: Use razorpay_flutter package
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  /// Dispose Razorpay resources
  void dispose() {
    _razorpay?.clear();
  }

  /// Start the promise fee payment flow
  /// 1. Creates Razorpay order via Cloud Function
  /// 2. Opens Razorpay Checkout
  Future<void> startPromiseFeePayment({
    required String donationId,
    required String userPhone,
    required String userEmail,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    _onSuccessCallback = onSuccess;
    _onErrorCallback = onError;

    // Validate API Key
    if (_razorpayKeyId.isEmpty ||
        _razorpayKeyId == 'rzp_test_YOUR_KEY_ID_HERE') {
      onError('Razorpay Key not configured. Please check your .env file.');
      return;
    }

    try {
      // Step 1: Generate unique idempotency key
      final String idempotencyKey = const Uuid().v4();

      // Step 2: Call Cloud Function to create order
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: _functionsRegion,
      ).httpsCallable('createPaymentOrder');

      final result = await callable.call({
        'donationId': donationId,
        'idempotencyKey': idempotencyKey,
      });

      final data = result.data as Map<dynamic, dynamic>;

      if (data['success'] == true) {
        // Step 3: Open Razorpay Checkout
        _openCheckout(
          orderId: data['orderId'],
          amount: data['amount'], // Should be 5000 paise (₹50)
          phone: userPhone,
          email: userEmail,
          onSuccess: onSuccess,
          onError: onError,
        );
      } else {
        onError('Failed to initiate payment order.');
      }
    } on FirebaseFunctionsException catch (e) {
      print('Cloud Function Error: ${e.code} - ${e.message}');
      onError('Error connecting to server: ${e.message}');
    } catch (e) {
      print('Payment Init Error: $e');
      onError('Error connecting to server.');
    }
  }

  /// Open Razorpay Checkout UI
  void _openCheckout({
    required String orderId,
    required int amount,
    required String phone,
    required String email,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) {
    print('Opening Razorpay Checkout...');
    print('Platform: ${_isWeb ? "Web" : "Mobile"}');
    print('Key: ${_razorpayKeyId.substring(0, 12)}...');
    print('Order ID: $orderId');

    if (_isWeb) {
      // Web: Use JavaScript interop
      razorpay_web.openRazorpayWeb(
        key: _razorpayKeyId,
        amount: amount,
        orderId: orderId,
        name: 'GiveLocally',
        description: 'Promise Fee (Refundable)',
        email: email,
        phone: phone,
        themeColor: '#4CAF50',
        onSuccess: (paymentId) {
          print('Web Payment Success: $paymentId');
          _onSuccessCallback?.call(paymentId);
        },
        onError: (error) {
          print('Web Payment Error: $error');
          _onErrorCallback?.call(error);
        },
      );
    } else {
      // Mobile: Use razorpay_flutter
      var options = {
        'key': _razorpayKeyId,
        'amount': amount,
        'name': 'GiveLocally',
        'description': 'Promise Fee (Refundable)',
        'order_id': orderId,
        'prefill': {'contact': phone, 'email': email},
        'theme': {
          'color': '#4CAF50',
        },
        'retry': {'enabled': true, 'max_count': 1},
        'send_sms_hash': true,
        'external': {
          'wallets': ['paytm', 'phonepe', 'googlepay'],
        },
      };

      try {
        _razorpay?.open(options);
      } catch (e) {
        print('Checkout Error: $e');
        onError('Failed to open payment: $e');
      }
    }
  }

  /// Handle successful payment authorization (Mobile only)
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('Razorpay Payment Authorized: ${response.paymentId}');
    print('Razorpay Order ID: ${response.orderId}');
    print('Razorpay Signature: ${response.signature}');
    _onSuccessCallback?.call(response.paymentId ?? 'success');
  }

  /// Handle payment error (Mobile only)
  void _handlePaymentError(PaymentFailureResponse response) {
    print('Razorpay Error: ${response.code} - ${response.message}');
    _onErrorCallback?.call('Payment Failed: ${response.message}');
  }

  /// Handle external wallet selection (Mobile only)
  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
  }
}
