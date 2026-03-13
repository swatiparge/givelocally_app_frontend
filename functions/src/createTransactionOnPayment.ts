/* eslint-disable max-len */
/* eslint-disable @typescript-eslint/no-explicit-any */

import * as functions from "firebase-functions/v2";
import {db} from "./config/firebase";
import {Timestamp} from "firebase-admin/firestore";

/**
 * Cloud Function: createTransactionOnPayment
 * Creates or updates a transaction document with correct pickup_code_expires (24h from now)
 * Called after successful Razorpay payment authorization
 */
export const createTransactionOnPayment = functions.https.onCall(
  {
    region: "asia-southeast1",
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
  },
  async (request: functions.https.CallableRequest<{
    donationId: string;
    razorpayPaymentId: string;
    razorpayOrderId: string;
    promiseFee: number;
  }>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Login required");
    }

    const { donationId, razorpayPaymentId, razorpayOrderId, promiseFee } = request.data;
    const receiverId = request.auth.uid;

    console.log(`[createTransactionOnPayment] Creating transaction:`, {
      donationId,
      razorpayPaymentId,
      receiverId,
    });

    try {
      // Get donation details
      const donationDoc = await db.collection("donations").doc(donationId).get();
      if (!donationDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Donation not found");
      }

      const donation = donationDoc.data();
      if (!donation) {
        throw new functions.https.HttpsError("not-found", "Donation data not found");
      }

      const donorId = donation.donorId || donation.userId;
      if (!donorId) {
        throw new functions.https.HttpsError("invalid-argument", "Donor ID not found");
      }

      // Check if transaction already exists
      const existingTransaction = await db
        .collection("transactions")
        .where("donationId", "==", donationId)
        .where("payment_status", "in", ["authorized", "captured"])
        .limit(1)
        .get();

      if (!existingTransaction.empty) {
        console.log(`[createTransactionOnPayment] Transaction already exists`);
        return {
          success: true,
          message: "Transaction already exists",
          transactionId: existingTransaction.docs[0].id,
        };
      }

      // Create transaction with correct 24-hour expiry
      const now = Timestamp.now();
      const pickupCodeExpires = Timestamp.fromDate(
        new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours from now
      );

      const transactionRef = await db.collection("transactions").add({
        donationId,
        donorId,
        receiverId,
        promise_fee: promiseFee || 9,
        payment_status: "authorized",
        razorpay_payment_id: razorpayPaymentId,
        razorpay_order_id: razorpayOrderId,
        pickup_code: Math.floor(1000 + Math.random() * 9000).toString(), // 4-digit code
        pickup_code_expires: pickupCodeExpires, // 24 hours from now
        pickup_code_used: false,
        authorization_expires: Timestamp.fromDate(
          new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours for UPI auth
        ),
        created_at: now,
        expires_at: pickupCodeExpires, // Same as pickup_code_expires
      });

      console.log(`[createTransactionOnPayment] Transaction created:`, {
        transactionId: transactionRef.id,
        pickup_code_expires: pickupCodeExpires.toDate(),
      });

      // Update donation status
      await donationDoc.ref.update({
        status: "reserved",
        claimed_by: receiverId,
        address_visible: true,
      });

      return {
        success: true,
        transactionId: transactionRef.id,
        pickupCode: Math.floor(1000 + Math.random() * 9000).toString(),
        pickupCodeExpires: pickupCodeExpires.toDate().toISOString(),
      };
    } catch (error: any) {
      console.error("[createTransactionOnPayment] Error:", error);
      throw new functions.https.HttpsError(
        "internal",
        error.message || "Failed to create transaction"
      );
    }
  }
);
