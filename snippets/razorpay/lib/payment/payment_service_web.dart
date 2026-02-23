import 'dart:js';
import 'package:js/js.dart';

/// JavaScript interop for Razorpay Web SDK
/// This file is only imported on Web platform

@JS()
class Razorpay {
  external Razorpay(RazorpayOptions options);
  external void open();
  external void on(String event, Function handler);
}

@JS()
@anonymous
class RazorpayOptions {
  external String get key;
  external int get amount;
  external String get currency;
  external String get name;
  external String get description;
  external String get order_id;
  external Prefill get prefill;
  external Theme get theme;
  external Function get handler;

  external factory RazorpayOptions({
    String key,
    int amount,
    String currency,
    String name,
    String description,
    String order_id,
    Prefill prefill,
    Theme theme,
    Function handler,
  });
}

@JS()
@anonymous
class Prefill {
  external String get name;
  external String get email;
  external String get contact;

  external factory Prefill({
    String name,
    String email,
    String contact,
  });
}

@JS()
@anonymous
class Theme {
  external String get color;

  external factory Theme({
    String color,
  });
}

@JS()
@anonymous
class PaymentResponse {
  external String get razorpay_payment_id;
  external String get razorpay_order_id;
  external String get razorpay_signature;
}

@JS()
@anonymous
class PaymentError {
  external String get code;
  external String get description;
  external String get source;
  external String get step;
  external String get reason;
}

@JS()
@anonymous
class PaymentFailedResponse {
  external PaymentError get error;
}

/// Open Razorpay Checkout on Web using JavaScript SDK
void openRazorpayWeb({
  required String key,
  required int amount,
  required String orderId,
  required String name,
  required String description,
  required String email,
  required String phone,
  required String themeColor,
  required Function(String) onSuccess,
  required Function(String) onError,
}) {
  try {
    // Store callbacks in JS context so they can be called from JS
    context['razorpaySuccessCallback'] = (JsObject response) {
      final paymentId = response['razorpay_payment_id'] as String?;
      print('Razorpay Web Success: $paymentId');
      onSuccess(paymentId ?? 'success');
    };

    context['razorpayErrorCallback'] = (JsObject response) {
      final error = response['error'] as JsObject?;
      final description = error?['description'] as String?;
      print('Razorpay Web Failed: $description');
      onError(description ?? 'Payment failed');
    };

    // Create the Razorpay options with UPI enabled
    final options = JsObject.jsify({
      'key': key,
      'amount': amount,
      'currency': 'INR',
      'name': name,
      'description': description,
      'order_id': orderId,
      'prefill': {
        'email': email,
        'contact': phone,
      },
      'theme': {
        'color': themeColor,
      },
      'handler': context['razorpaySuccessCallback'],
      // Enable all payment methods including UPI
      'method': {
        'upi': true,
        'card': true,
        'netbanking': true,
        'wallet': true,
        'emi': false, // Disable EMI for small amount
        'paylater': false, // Disable paylater for small amount
      },
      // Configure UPI specifically
      'config': {
        'display': {
          'hide': [
            // Don't hide anything, show all
          ],
        },
      },
      // Enable UPI intent for mobile web
      'upi': {
        'flow': 'collect', // or 'intent' for mobile apps
        'vpa': '', // Let user enter their UPI ID
      },
    });

    // Create Razorpay instance
    final razorpayConstructor = context['Razorpay'];
    final razorpay = (razorpayConstructor as JsFunction).apply([options]);

    // Set up error handler
    razorpay
        .callMethod('on', ['payment.failed', context['razorpayErrorCallback']]);

    // Open checkout
    razorpay.callMethod('open');
    print('Razorpay checkout opened successfully with UPI enabled');
  } catch (e) {
    print('Error opening Razorpay Web: $e');
    onError('Failed to open payment: $e');
  }
}
