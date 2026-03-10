import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Workaround for Cloud Function permission issues
/// Handles pickup verification directly via Firestore transactions
class PickupVerificationHelper {
  /// Verify pickup code WITHOUT using Cloud Function
  /// Returns true if successful, throws exception with message if failed
  static Future<bool> verifyPickupDirectly({
    required String donationId,
    required String pickupCode,
    required String userId,
  }) async {
    debugPrint("[DirectVerification] Starting...");
    debugPrint("  Donation ID: $donationId");
    debugPrint("  Pickup Code: $pickupCode");
    debugPrint("  User ID: $userId");

    // 1. Verify user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("Please log in to verify the pickup");
    }

    if (currentUser.uid != userId) {
      throw Exception("User ID mismatch. Please refresh and try again.");
    }

    // 2. Get donation and verify donor
    final donationDoc = await FirebaseFirestore.instance
        .collection('donations')
        .doc(donationId)
        .get();

    if (!donationDoc.exists) {
      throw Exception("Donation not found");
    }

    final donationData = donationDoc.data()!;
    final donationDonorId = donationData['donorId'] ?? donationData['userId'];

    debugPrint("[DirectVerification] Donation donorId: $donationDonorId");
    debugPrint("[DirectVerification] Current user: ${currentUser.uid}");

    if (donationDonorId != currentUser.uid) {
      throw Exception(
        "Only the donor can verify pickup codes.\n\n" +
            "Expected donor: $donationDonorId\n" +
            "Your ID: ${currentUser.uid}\n\n" +
            "You are currently logged in as a different user than the donation donor.",
      );
    }

    // 3. Find transaction
    var transactionQuery = await FirebaseFirestore.instance
        .collection('transactions')
        .where('donationId', isEqualTo: donationId)
        .where('donorId', isEqualTo: currentUser.uid)
        .limit(1)
        .get();

    // Try snake_case if empty
    if (transactionQuery.docs.isEmpty) {
      transactionQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('donation_id', isEqualTo: donationId)
          .limit(1)
          .get();
    }

    // Try without donorId filter
    if (transactionQuery.docs.isEmpty) {
      transactionQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('donationId', isEqualTo: donationId)
          .limit(1)
          .get();
    }

    if (transactionQuery.docs.isEmpty) {
      throw Exception("No transaction found for this donation.");
    }

    final transactionDoc = transactionQuery.docs.first;
    final transactionData = transactionDoc.data();
    final transactionId = transactionDoc.id;

    debugPrint("[DirectVerification] Transaction found: $transactionId");

    // 4. Validate pickup code
    final actualCode = transactionData['pickup_code']?.toString();
    if (actualCode != pickupCode) {
      throw Exception(
        "Invalid pickup code.\n\n" +
            "Entered: $pickupCode\n" +
            "Expected: $actualCode",
      );
    }

    // 5. Check if already used
    final isUsed = transactionData['pickup_code_used'] ?? false;
    if (isUsed) {
      throw Exception("This pickup has already been completed.");
    }

    // 6. Check expiry
    final expiresAt = transactionData['pickup_code_expires'];
    if (expiresAt != null) {
      DateTime expiry;
      if (expiresAt is Timestamp) {
        expiry = expiresAt.toDate();
      } else {
        expiry = DateTime.parse(expiresAt.toString());
      }

      if (DateTime.now().isAfter(expiry)) {
        throw Exception("This pickup code has expired.");
      }
    }

    // 7. Update transaction and donation using batch
    final batch = FirebaseFirestore.instance.batch();

    // Update transaction
    batch.update(
      FirebaseFirestore.instance.collection('transactions').doc(transactionId),
      {
        'pickup_code_used': true,
        'pickup_completed_at': FieldValue.serverTimestamp(),
        'payment_status': 'captured',
        'captured_at': FieldValue.serverTimestamp(),
      },
    );

    // Update donation
    batch.update(
      FirebaseFirestore.instance.collection('donations').doc(donationId),
      {'status': 'completed', 'completed_at': FieldValue.serverTimestamp()},
    );

    // Award karma to donor
    batch.update(
      FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
      {
        'karma_points': FieldValue.increment(100),
        'total_donations': FieldValue.increment(1),
      },
    );

    // Award karma to receiver
    final receiverId = transactionData['receiverId'];
    if (receiverId != null) {
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(receiverId),
        {
          'karma_points': FieldValue.increment(10),
          'total_received': FieldValue.increment(1),
        },
      );
    }

    await batch.commit();

    debugPrint("[DirectVerification] SUCCESS! Pickup completed");
    return true;
  }
}
