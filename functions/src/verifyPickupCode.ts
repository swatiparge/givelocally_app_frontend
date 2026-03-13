/* eslint-disable max-len, @typescript-eslint/no-non-null-assertion */
/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/no-unused-vars */
/* eslint-disable-next-line @typescript-eslint/no-unused-vars */
/* eslint-disable require-jsdoc */
/* eslint-disable no-case-declarations */

import * as functions from "firebase-functions/v2";
import {db} from "./config/firebase";
import {FieldValue} from "firebase-admin/firestore";
import Razorpay from "razorpay";

interface VerifyPickupCodeData {
  donationId: string;
  pickupCode: string;
}

/**
 * Cloud Function: verifyPickupCode
 * Verifies the 4-digit pickup code and captures the payment
 * Trigger: Donor enters pickup code
 */
export const verifyPickupCode = functions.https.onCall(
  {
    region: "asia-southeast1",
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
  },
  async (request: functions.https.CallableRequest<VerifyPickupCodeData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Login required");
    }

    // Initialize Razorpay
    const razorpay = new Razorpay({
      key_id: process.env.RAZORPAY_KEY_ID || "",
      key_secret: process.env.RAZORPAY_KEY_SECRET || "",
    });

    const userId = request.auth.uid;
    const {donationId, pickupCode} = request.data;

    console.log(`[verifyPickupCode] Starting verification:`);
    console.log(`  User ID: ${userId}`);
    console.log(`  Donation ID: ${donationId}`);
    console.log(`  Pickup Code: ${pickupCode}`);

    // 1. Verify user is the donor of this donation
    console.log(`[verifyPickupCode] Fetching donation document...`);
    const donationDoc = await db.collection("donations").doc(donationId).get();

    if (!donationDoc.exists) {
      console.log(`[verifyPickupCode] ERROR: Donation ${donationId} not found`);
      throw new functions.https.HttpsError("not-found", "Donation not found");
    }

    const donation = donationDoc.data();
    console.log(`[verifyPickupCode] Donation found:`);
    console.log(`  donorId: ${donation?.donorId}`);
    console.log(`  userId: ${donation?.userId}`);
    console.log(`  status: ${donation?.status}`);
    console.log(`  Authenticated user: ${userId}`);

    // Check both donorId and userId fields
    const donationOwnerId = donation?.donorId || donation?.userId;
    
    if (donationOwnerId !== userId) {
      console.log(`[verifyPickupCode] ERROR: Permission denied`);
      console.log(`  Expected donorId: ${donationOwnerId}`);
      console.log(`  Actual userId: ${userId}`);
      throw new functions.https.HttpsError(
          "permission-denied",
          `Only the donor can verify pickup codes. Expected: ${donationOwnerId}, Got: ${userId}`
      );
    }

    console.log(`[verifyPickupCode] Donor verification passed`);

    // 2. Find the transaction for this donation
    console.log(`[verifyPickupCode] Querying transaction...`);
    const transactionsSnapshot = await db
        .collection("transactions")
        .where("donationId", "==", donationId)
        .where("donorId", "==", userId)
        .where("payment_status", "in", ["authorized", "captured"]) // Accept both statuses
        .limit(1)
        .get();

    console.log(`[verifyPickupCode] Transaction query returned ${transactionsSnapshot.size} docs`);

    if (transactionsSnapshot.empty) {
      console.log(`[verifyPickupCode] ERROR: No transaction found`);
      console.log(`  Query: donationId=${donationId}, donorId=${userId}, payment_status in [authorized, captured]`);
      throw new functions.https.HttpsError(
          "not-found",
          "No active transaction found for this donation"
      );
    }

    const transactionDoc = transactionsSnapshot.docs[0];
    const transaction = transactionDoc.data();
    const transactionId = transactionDoc.id;

    console.log(`[verifyPickupCode] Transaction found:`);
    console.log(`  Transaction ID: ${transactionId}`);
    console.log(`  payment_status: ${transaction.payment_status}`);
    console.log(`  pickup_code: ${transaction.pickup_code}`);
    console.log(`  pickup_code_used: ${transaction.pickup_code_used}`);
    console.log(`  Expected code: ${pickupCode}`);

    // 3. Validate Pickup Code
    if (transaction.pickup_code !== pickupCode) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid pickup code"
      );
    }

    // 4. Check Expiry
    const now = new Date();
    const expiresAt = transaction.pickup_code_expires?.toDate();
    
    if (expiresAt && now > expiresAt) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Pickup code has expired"
      );
    }

    // 5. Check if already used
    if (transaction.pickup_code_used) {
      throw new functions.https.HttpsError(
        "already-exists",
        "Pickup code already used"
      );
    }

    try {
      // 6. Fetch and capture the Razorpay payment
      const razorpayPaymentId = transaction.razorpay_payment_id;
      
      if (!razorpayPaymentId) {
        throw new Error("Razorpay payment ID not found in transaction");
      }

      const payment = await razorpay.payments.fetch(razorpayPaymentId);

      if (payment.status === "authorized") {
        // Capture the payment (charge the promise fee)
        await razorpay.payments.capture(
          razorpayPaymentId,
          transaction.promise_fee * 100,
          "INR"
        );
        console.log(`Payment captured: ${razorpayPaymentId}`);
      } else if (payment.status === "captured") {
        // Already captured (race condition), proceed with completion
        console.log(`Payment already captured: ${razorpayPaymentId}`);
      } else {
        throw new Error(`Invalid payment status: ${payment.status}`);
      }

      // 7. Update Transaction and Donation
      const batch = db.batch();

      batch.update(db.collection("transactions").doc(transactionId), {
        payment_status: "captured",
        pickup_code_used: true,
        pickup_completed_at: FieldValue.serverTimestamp(),
        captured_at: FieldValue.serverTimestamp(),
      });

      batch.update(db.collection("donations").doc(donationId), {
        status: "completed",
        completed_at: FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // 8. Award Karma to both donor and receiver
      const receiverId = transaction.receiverId;

      // Donor gets +100 karma for completing donation
      await db.collection("users").doc(userId).update({
        karma_points: FieldValue.increment(100),
        total_donations: FieldValue.increment(1),
      });

      // Receiver gets +10 karma for completing pickup
      if (receiverId) {
        await db.collection("users").doc(receiverId).update({
          karma_points: FieldValue.increment(10),
          total_received: FieldValue.increment(1),
        });
      }

      // 9. Send notification to receiver (optional - implement with FCM)
      // await sendNotification(receiverId, {
      //   title: "Pickup Completed!",
      //   body: "Thank you for completing the pickup. You earned +10 karma!",
      // });

      console.log(`Pickup completed for donation: ${donationId} by user: ${userId}`);

      return {
        success: true,
        message: "Pickup verified successfully. Payment processed.",
        karmaAwarded: {
          donor: 100,
          receiver: 10,
        },
      };
    } catch (error: any) {
      console.error("Error verifying pickup code:", error);
      
      throw new functions.https.HttpsError(
        "internal",
        error.description || error.message || "Failed to verify pickup code"
      );
    }
  }
);
