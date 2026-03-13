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

  // Store donation data for transaction creation
  String _lastOrderId = '';
  String _lastDonationId = '';
  String _lastDonorId = '';
  String _currentUserId = '';

  RazorpayService(this.context) : _razorpay = Razorpay() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint("Payment Success: ${response.paymentId}");

    // Create transaction document with correct 24h expiry
    try {
      final transactionRef = await FirebaseFirestore.instance
          .collection('transactions')
          .add({
            'razorpay_payment_id': response.paymentId,
            'razorpay_order_id': _lastOrderId,
            'payment_status': 'authorized',
            'promise_fee': 9,
            'pickup_code': _generatePickupCode(),
            'pickup_code_expires': Timestamp.fromDate(
              DateTime.now().add(Duration(hours: 24)),
            ),
            'authorization_expires': Timestamp.fromDate(
              DateTime.now().add(Duration(hours: 24)),
            ),
            'pickup_code_used': false,
            'created_at': FieldValue.serverTimestamp(),
            'expires_at': Timestamp.fromDate(
              DateTime.now().add(Duration(hours: 24)),
            ),
            'donationId': _lastDonationId,
            'donorId': _lastDonorId,
            'receiverId': _currentUserId,
          });

      debugPrint("Transaction created: ${transactionRef.id}");
    } catch (e) {
      debugPrint("Error creating transaction: $e");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment Successful! Item Reserved.")),
    );
  }

  String _generatePickupCode() {
    return (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
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
    // Store donation data for transaction creation on payment success
    _lastOrderId = orderId;
    _lastDonationId =
        donation['id']?.toString() ?? donation['donationId']?.toString() ?? '';
    _lastDonorId =
        donation['donorId']?.toString() ?? donation['userId']?.toString() ?? '';
    _currentUserId = user.uid?.toString() ?? '';

    debugPrint("Stored donation data for transaction:");
    debugPrint("  - donationId: $_lastDonationId");
    debugPrint("  - donorId: $_lastDonorId");
    debugPrint("  - userId: $_currentUserId");
    debugPrint("  - orderId: $_lastOrderId");

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
