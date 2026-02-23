import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';

class RazorpayService {
  final Razorpay _razorpay;
  final BuildContext context;

  RazorpayService(this.context) : _razorpay = Razorpay() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint("Payment Success: ${response.paymentId}");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment Successful! Item Reserved.")),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("Payment Error: ${response.code} - ${response.message}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet: ${response.walletName}");
  }

  Future<void> reserveItem(Map<String, dynamic> donation) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.userModel;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to reserve items")),
      );
      return;
    }

    try {
      final String donationId = donation['id'] ?? donation['donationId'] ?? '';
      final String idempotencyKey = const Uuid().v4();

      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('createPaymentOrder');

      final results = await callable.call(<String, dynamic>{
        'donationId': donationId,
        'idempotencyKey': idempotencyKey,
      });

      final data = results.data;
      if (data['success'] != true) {
        throw Exception("Failed to create order");
      }

      final String orderId = data['orderId'];
      final String razorpayKey = data['key_id'];

      var options = {
        'key': razorpayKey,
        'amount': data['amount'],
        'name': 'GiveLocally',
        'order_id': orderId,
        'description': 'Platform Fee for ${donation['title']}',
        'prefill': {
          'contact': user.phone,
          'email': user.email ?? '${user.phone}@givelocally.app'
        },
        'theme': {'color': '#66BB6A'}
      };

      _razorpay.open(options);
    } catch (e) {
      debugPrint("Reserve Item Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }
}
