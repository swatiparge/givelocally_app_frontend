import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/payment_models.dart';

/// Service for handling Razorpay payments
class PaymentService {
  final RazorpayConfig config;

  PaymentService(this.config);

  /// Initialize Razorpay (platform-specific)
  void init() {
    if (!kIsWeb) {
      // Mobile initialization if needed
    }
  }

  /// Dispose resources
  void dispose() {
    if (!kIsWeb) {
      // Mobile cleanup if needed
    }
  }

  /// Start payment flow
  /// Returns order ID on success
  Future<String?> startPayment({
    required String donationId,
    required String userPhone,
    required String userEmail,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) async {
    try {
      // Step 1: Generate unique idempotency key
      final String idempotencyKey = const Uuid().v4();

      // Step 2: Call Cloud Function to create order
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: config.functionRegion,
      ).httpsCallable('createPaymentOrder');

      final result = await callable.call({
        'donationId': donationId,
        'idempotencyKey': idempotencyKey,
        'amount': config.amount,
      });

      final data = result.data as Map<dynamic, dynamic>;

      if (data['success'] == true) {
        // Step 3: Open Razorpay Checkout
        onSuccess(data['orderId'] ?? '');
        return data['orderId'] as String?;
      } else {
        onError('Failed to initiate payment order.');
        return null;
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function Error: ${e.code} - ${e.message}');
      onError('Error connecting to server: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Payment Init Error: $e');
      onError('Error connecting to server.');
      return null;
    }
  }

  /// Verify pickup code (for donor)
  Future<bool> verifyPickupCode({
    required String donationId,
    required String pickupCode,
    String? errorMessage,
  }) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: config.functionRegion,
      ).httpsCallable('verifyPickupCode');

      final result = await callable.call({
        'donationId': donationId,
        'pickupCode': pickupCode,
      });

      final data = result.data as Map<dynamic, dynamic>;
      return data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Verify Error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Verify Error: $e');
      return false;
    }
  }

  /// Get transaction by ID
  Stream<RazorpayTransaction?> getTransaction(String transactionId) {
    return FirebaseFirestore.instance
        .collection('transactions')
        .doc(transactionId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return RazorpayTransaction.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    });
  }

  /// Get all transactions for a user
  Stream<List<RazorpayTransaction>> getUserTransactions(String userId) {
    return FirebaseFirestore.instance
        .collection('transactions')
        .where('receiverId', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RazorpayTransaction.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }
}
