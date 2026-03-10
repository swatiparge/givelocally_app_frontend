import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility class to debug and verify transaction data
class TransactionDebugHelper {
  /// Fetch and log transaction data for debugging
  static Future<Map<String, dynamic>?> debugTransaction(
    String donationId, {
    String? expectedPickupCode,
  }) async {
    try {
      debugPrint('════════════════════════════════════════');
      debugPrint('TRANSACTION DEBUG for donation: $donationId');
      debugPrint('════════════════════════════════════════');

      // Query transactions collection - try both field names
      var querySnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('donationId', isEqualTo: donationId)
          .limit(5)
          .get();

      // Try snake_case if camelCase returns empty
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('transactions')
            .where('donation_id', isEqualTo: donationId)
            .limit(5)
            .get();
      }

      debugPrint('Found ${querySnapshot.docs.length} transaction(s)');

      if (querySnapshot.docs.isEmpty) {
        debugPrint('❌ ERROR: No transaction found for donation $donationId');
        return null;
      }

      for (int i = 0; i < querySnapshot.docs.length; i++) {
        final doc = querySnapshot.docs[i];
        final data = doc.data();

        debugPrint('');
        debugPrint('Transaction ${i + 1}:');
        debugPrint('  Document ID: ${doc.id}');
        debugPrint('  donationId: ${data['donationId']}');
        debugPrint('  donorId: ${data['donorId']}');
        debugPrint('  receiverId: ${data['receiverId']}');
        debugPrint('  razorpay_payment_id: ${data['razorpay_payment_id']}');
        debugPrint('  razorpay_order_id: ${data['razorpay_order_id']}');
        debugPrint('  pickup_code: ${data['pickup_code']}');
        debugPrint('  payment_status: ${data['payment_status']}');
        debugPrint('  pickup_code_used: ${data['pickup_code_used']}');
        debugPrint('  promise_fee: ${data['promise_fee']}');

        final expiresAt = data['pickup_code_expires'];
        if (expiresAt != null) {
          final expiry = expiresAt is Timestamp
              ? expiresAt.toDate()
              : DateTime.now();
          final remaining = expiry.difference(DateTime.now());
          debugPrint(
            '  pickup_code_expires: $expiry (${remaining.inHours}h ${remaining.inMinutes % 60}m remaining)',
          );
        }

        // Validate required fields
        final issues = <String>[];

        if (data['razorpay_payment_id'] == null ||
            data['razorpay_payment_id'].toString().isEmpty) {
          issues.add('❌ Missing razorpay_payment_id');
        } else if (!data['razorpay_payment_id'].toString().startsWith('pay_')) {
          issues.add(
            '⚠️  razorpay_payment_id format looks invalid (should start with "pay_")',
          );
        }

        if (data['pickup_code'] == null ||
            data['pickup_code'].toString().isEmpty) {
          issues.add('❌ Missing pickup_code');
        } else if (data['pickup_code'].toString().length != 4) {
          issues.add('⚠️  pickup_code is not 4 digits: ${data['pickup_code']}');
        }

        if (data['payment_status'] != 'authorized' &&
            data['payment_status'] != 'captured') {
          issues.add(
            '⚠️ payment_status is not valid (should be "authorized" or "captured"): ${data['payment_status']}',
          );
        }

        if (data['donorId'] == null || data['donorId'].toString().isEmpty) {
          issues.add('❌ Missing donorId');
        }

        if (data['receiverId'] == null ||
            data['receiverId'].toString().isEmpty) {
          issues.add('❌ Missing receiverId');
        }

        // Check pickup code match if provided
        if (expectedPickupCode != null) {
          if (data['pickup_code'] == expectedPickupCode) {
            debugPrint('  ✓ Pickup code matches: $expectedPickupCode');
          } else {
            issues.add(
              '❌ Pickup code mismatch: expected $expectedPickupCode, got ${data['pickup_code']}',
            );
          }
        }

        if (issues.isEmpty) {
          debugPrint('  ✓ All required fields present and valid');
        } else {
          debugPrint('  Issues found:');
          for (final issue in issues) {
            debugPrint('    $issue');
          }
        }
      }

      debugPrint('════════════════════════════════════════');
      return querySnapshot.docs.first.data();
    } catch (e) {
      debugPrint('❌ Error fetching transaction: $e');
      debugPrint('════════════════════════════════════════');
      return null;
    }
  }

  /// Check if a transaction exists and is valid for pickup verification
  static Future<bool> canVerifyPickup({
    required String donationId,
    required String donorId,
    String? expectedPickupCode,
  }) async {
    try {
      // Query by donationId first
      var querySnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('donationId', isEqualTo: donationId)
          .where('pickup_code_used', isEqualTo: false)
          .limit(1)
          .get();

      // Try snake_case if needed
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('transactions')
            .where('donation_id', isEqualTo: donationId)
            .where('pickup_code_used', isEqualTo: false)
            .limit(1)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        debugPrint('❌ No valid transaction found for pickup verification');
        return false;
      }

      final data = querySnapshot.docs.first.data();

      // Verify donor
      if (data['donorId'] != donorId) {
        debugPrint('❌ Donor ID mismatch');
        return false;
      }

      // Check pickup code if provided
      if (expectedPickupCode != null &&
          data['pickup_code'] != expectedPickupCode) {
        debugPrint('❌ Pickup code mismatch');
        return false;
      }

      // Check expiry
      final expiresAt = data['pickup_code_expires'];
      if (expiresAt != null) {
        final expiry = expiresAt is Timestamp
            ? expiresAt.toDate()
            : DateTime.now();
        if (DateTime.now().isAfter(expiry)) {
          debugPrint('❌ Pickup code has expired');
          return false;
        }
      }

      debugPrint('✓ Transaction is valid for pickup verification');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking transaction: $e');
      return false;
    }
  }
}
