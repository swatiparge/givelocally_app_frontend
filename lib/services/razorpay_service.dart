import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

    final String donationId = (donation['id'] ?? donation['donationId'] ?? '')
        .toString();
    final String idempotencyKey = const Uuid().v4();

    try {
      // IDEMPOTENCY CHECK: Store key before payment (AGENTS.md 6.1)
      // This prevents double-charges on flaky networks
      final idempotencyRef = FirebaseFirestore.instance
          .collection('idempotency_keys')
          .doc(idempotencyKey);

      // Check if key already exists (shouldn't, but safety check)
      final existingKey = await idempotencyRef.get();
      if (existingKey.exists) {
        // Return existing order data
        final existingData = existingKey.data()!;
        if (existingData['orderId'] != null) {
          _openRazorpayCheckout(
            orderId: existingData['orderId'],
            razorpayKey: existingData['razorpayKey'] ?? '',
            amount: existingData['amount'] ?? 5000,
            donation: donation,
            user: user,
          );
          return;
        }
      }

      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('createPaymentOrder');

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

      // Store idempotency key for 24 hours
      await idempotencyRef.set({
        'orderId': orderId,
        'razorpayKey': razorpayKey,
        'amount': data['amount'],
        'donationId': donationId,
        'userId': user.uid,
        'status': 'created',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
      });

      _openRazorpayCheckout(
        orderId: orderId,
        razorpayKey: razorpayKey,
        amount: data['amount'],
        donation: donation,
        user: user,
      );
    } catch (e) {
      debugPrint("Reserve Item Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    }
  }

  void _openRazorpayCheckout({
    required String orderId,
    required String razorpayKey,
    required int amount,
    required Map<String, dynamic> donation,
    required dynamic user,
  }) {
    var options = {
      'key': razorpayKey,
      'amount': amount,
      'name': 'GiveLocally',
      'order_id': orderId,
      'description': 'Platform Fee for ${donation['title']}',
      'prefill': {
        'contact': user.phone,
        'email': user.email ?? '${user.phone}@givelocally.app',
      },
      'theme': {'color': '#66BB6A'},
    };

    _razorpay.open(options);
  }
}
