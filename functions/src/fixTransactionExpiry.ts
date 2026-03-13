/* eslint-disable max-len */
/* eslint-disable @typescript-eslint/no-explicit-any */

import * as functions from "firebase-functions/v2";
import {db} from "./config/firebase";
import {Timestamp} from "firebase-admin/firestore";

/**
 * Cloud Function: fixTransactionExpiry
 * One-time fix to update existing transactions with correct pickup_code_expires
 * This ensures all transactions have the 24-hour expiry instead of 30-day donation expiry
 */
export const fixTransactionExpiry = functions.https.onCall(
  {
    region: "asia-southeast1",
  },
  async (request: functions.https.CallableRequest<{donationId?: string}>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Login required");
    }

    const { donationId } = request.data || {};
    const userId = request.auth.uid;

    console.log(`[fixTransactionExpiry] Starting fix for user: ${userId}, donationId: ${donationId}`);

    try {
      let query;
      if (donationId) {
        // Fix specific donation's transaction
        query = await db
          .collection("transactions")
          .where("donationId", "==", donationId)
          .get();
      } else {
        // Fix all transactions for this user (if admin)
        // For now, only fix own transactions
        query = await db
          .collection("transactions")
          .where("receiverId", "==", userId)
          .where("payment_status", "in", ["authorized", "captured"])
          .get();
      }

      console.log(`[fixTransactionExpiry] Found ${query.size} transactions to fix`);

      let fixedCount = 0;
      const batch = db.batch();

      for (const doc of query.docs) {
        const data = doc.data();
        
        // Check if pickup_code_expires already exists
        if (data.pickup_code_expires) {
          console.log(`[fixTransactionExpiry] Transaction ${doc.id} already has pickup_code_expires`);
          continue;
        }

        // If expires_at exists but pickup_code_expires doesn't, copy it
        // This assumes expires_at was set correctly (24h from payment)
        if (data.expires_at) {
          batch.update(doc.ref, {
            pickup_code_expires: data.expires_at,
          });
          fixedCount++;
          console.log(`[fixTransactionExpiry] Fixed transaction ${doc.id}`);
        } else {
          // If no expiry at all, set to 24h from now
          const newExpiry = Timestamp.fromDate(
            new Date(Date.now() + 24 * 60 * 60 * 1000)
          );
          batch.update(doc.ref, {
            pickup_code_expires: newExpiry,
            expires_at: newExpiry,
          });
          fixedCount++;
          console.log(`[fixTransactionExpiry] Set new expiry for transaction ${doc.id}`);
        }
      }

      if (fixedCount > 0) {
        await batch.commit();
        console.log(`[fixTransactionExpiry] Fixed ${fixedCount} transactions`);
      }

      return {
        success: true,
        fixedCount,
        message: `Fixed ${fixedCount} transaction(s)`,
      };
    } catch (error: any) {
      console.error("[fixTransactionExpiry] Error:", error);
      throw new functions.https.HttpsError(
        "internal",
        error.message || "Failed to fix transaction expiry"
      );
    }
  }
);
