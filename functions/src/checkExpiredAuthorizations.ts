/* eslint-disable max-len */
/* eslint-disable @typescript-eslint/no-explicit-any */

import * as functions from "firebase-functions";
import {db} from "./config/firebase";
import {Timestamp, FieldValue} from "firebase-admin/firestore";
import Razorpay from "razorpay";

/**
 * Cloud Function: checkExpiredAuthorizations
 * Scheduled function that runs every 10 minutes to check for expired pickup codes
 * and automatically forfeit the promise fee.
 *
 * Trigger: Pub/Sub Schedule (every 10 minutes)
 */
export const checkExpiredAuthorizations = functions.pubsub
  .schedule("*/10 * * * *") // Every 10 minutes
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    console.log("[checkExpiredAuthorizations] Starting scheduled job...");

    try {
      // Initialize Razorpay
      const razorpay = new Razorpay({
        key_id: process.env.RAZORPAY_KEY_ID || "",
        key_secret: process.env.RAZORPAY_KEY_SECRET || "",
      });

      const now = Timestamp.now();

      // Query for expired transactions
      // pickup_code_used == false (not completed)
      // expires_at < now (expired)
      // payment_status in ["authorized", "captured"] (has valid payment)
      const expiredQuery = await db
        .collection("transactions")
        .where("pickup_code_used", "==", false)
        .where("expires_at", "<=", now)
        .where("payment_status", "in", ["authorized", "captured"])
        .get();

      console.log(
        `[checkExpiredAuthorizations] Found ${expiredQuery.size} expired transactions`
      );

      if (expiredQuery.empty) {
        console.log("[checkExpiredAuthorizations] No expired transactions found");
        return;
      }

      const batch = db.batch();
      let processedCount = 0;
      let capturedCount = 0;
      let expiredCount = 0;
      let failedCount = 0;

      for (const doc of expiredQuery.docs) {
        const transaction = doc.data();
        const transactionId = doc.id;

        try {
          console.log(
            `[checkExpiredAuthorizations] Processing transaction: ${transactionId}`
          );

          // Get the Razorpay payment ID
          const razorpayPaymentId = transaction.razorpay_payment_id;

          if (!razorpayPaymentId) {
            console.error(
              `[checkExpiredAuthorizations] No Razorpay payment ID for transaction ${transactionId}`
            );
            failedCount++;
            continue;
          }

          let paymentStatus = "expired";
          let shouldRelist = true;

          // Try to capture the payment (forfeit the promise fee)
          if (transaction.payment_status === "authorized") {
            try {
              console.log(
                `[checkExpiredAuthorizations] Attempting to capture payment: ${razorpayPaymentId}`
              );

              // Capture the payment
              await razorpay.payments.capture(
                razorpayPaymentId,
                transaction.promise_fee * 100, // Amount in paise
                "INR"
              );

              paymentStatus = "captured";
              capturedCount++;
              console.log(
                `[checkExpiredAuthorizations] Payment captured successfully: ${razorpayPaymentId}`
              );

      // Deduct karma for no-show (-20 karma)
      const receiverId = transaction.receiverId;
      if (receiverId) {
        await db.collection("users").doc(receiverId).update({
          karma_points: FieldValue.increment(-20),
        });
                console.log(
                  `[checkExpiredAuthorizations] Deducted 20 karma from receiver: ${receiverId}`
                );
              }

              // Send FCM notification to receiver about forfeit
              // (Implement FCM notification here if needed)
            } catch (error: any) {
              console.error(
                `[checkExpiredAuthorizations] Error capturing payment:`,
                error
              );

              // Check if authorization has expired (24-hour UPI window)
              if (
                error.description &&
                (error.description.includes("expired") ||
                  error.description.includes("Authorization has expired"))
              ) {
                console.log(
                  `[checkExpiredAuthorizations] Authorization expired, marking as expired: ${razorpayPaymentId}`
                );
                paymentStatus = "expired";
                expiredCount++;

            // Still deduct karma for no-show
            const receiverId = transaction.receiverId;
            if (receiverId) {
              await db.collection("users").doc(receiverId).update({
                karma_points: FieldValue.increment(-20),
              });
                  console.log(
                    `[checkExpiredAuthorizations] Deducted 20 karma from receiver: ${receiverId}`
                  );
                }
              } else {
                // Other error - mark as failed but don't crash
                failedCount++;
                console.error(
                  `[checkExpiredAuthorizations] Unexpected error:`,
                  error
                );
                shouldRelist = false;
              }
            }
          } else if (transaction.payment_status === "captured") {
            // Already captured (race condition from previous run)
            console.log(
              `[checkExpiredAuthorizations] Payment already captured: ${razorpayPaymentId}`
            );
            capturedCount++;
          }

          // Update transaction status
          const transactionRef = db.collection("transactions").doc(transactionId);
          batch.update(transactionRef, {
            payment_status: paymentStatus,
            pickup_code_used: true,
            auto_forfeited: true,
            forfeited_at: Timestamp.now(),
          });

          // Relist the donation if it should be relisted
          if (shouldRelist && transaction.donationId) {
            const donationRef = db
              .collection("donations")
              .doc(transaction.donationId);
            batch.update(donationRef, {
              status: "active",
              claimed_by: null,
              reserved_at: null,
              address_visible: false,
            });
            console.log(
              `[checkExpiredAuthorizations] Relisted donation: ${transaction.donationId}`
            );
          }

          processedCount++;
        } catch (error: any) {
          console.error(
            `[checkExpiredAuthorizations] Error processing transaction ${transactionId}:`,
            error
          );
          failedCount++;
        }
      }

      // Commit all updates in batch
      if (processedCount > 0) {
        await batch.commit();
        console.log(
          `[checkExpiredAuthorizations] Batch commit successful. Processed: ${processedCount}, Captured: ${capturedCount}, Expired: ${expiredCount}, Failed: ${failedCount}`
        );
      } else {
        console.log(
          "[checkExpiredAuthorizations] No transactions processed successfully"
        );
      }

      return {
        processed: processedCount,
        captured: capturedCount,
        expired: expiredCount,
        failed: failedCount,
      };
    } catch (error: any) {
      console.error(
        "[checkExpiredAuthorizations] Critical error in scheduled function:",
        error
      );
      // Don't throw - this would cause Cloud Functions to retry indefinitely
      return {
        error: error.message,
        processed: 0,
      };
    }
  });
