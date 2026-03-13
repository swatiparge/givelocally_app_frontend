/* eslint-disable max-len */
/* eslint-disable @typescript-eslint/no-explicit-any */

import * as functions from "firebase-functions/v2";
import {db} from "./config/firebase";

/**
 * Cloud Function: getTransaction
 * Retrieves transaction data from the transactions collection
 * Used by the pickup code screen to get the correct pickup_code_expires
 */
export const getTransaction = functions.https.onCall(
  {
    region: "asia-southeast1",
  },
  async (request: functions.https.CallableRequest<{transactionId?: string, donationId?: string}>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Login required");
    }

    const { transactionId, donationId } = request.data;
    const userId = request.auth.uid;

    console.log(`[getTransaction] Request received:`, { transactionId, donationId, userId });

    try {
      let query;

      if (transactionId) {
        // Get by transaction ID
        query = db.collection("transactions").doc(transactionId);
        const doc = await query.get();

        if (!doc.exists) {
          console.log(`[getTransaction] Transaction not found: ${transactionId}`);
          return null;
        }

        const data = doc.data();
        if (!data) {
          return null;
        }

        // Verify user has permission to view this transaction
        if (data.donorId !== userId && data.receiverId !== userId) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "You can only view your own transactions"
          );
        }

        console.log(`[getTransaction] Transaction found:`, {
          id: doc.id,
          pickup_code_expires: data.pickup_code_expires,
          expires_at: data.expires_at,
        });

        return {
          ...data,
          id: doc.id,
        };
      } else if (donationId) {
        // Get by donation ID
        const snapshot = await db
          .collection("transactions")
          .where("donationId", "==", donationId)
          .where("payment_status", "in", ["authorized", "captured"])
          .limit(1)
          .get();

        if (snapshot.empty) {
          console.log(`[getTransaction] No transaction found for donation: ${donationId}`);
          return null;
        }

        const doc = snapshot.docs[0];
        const data = doc.data();

        if (!data) {
          return null;
        }

        // Verify user has permission
        if (data.donorId !== userId && data.receiverId !== userId) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "You can only view your own transactions"
          );
        }

        console.log(`[getTransaction] Transaction found by donationId:`, {
          id: doc.id,
          donationId,
          pickup_code_expires: data.pickup_code_expires,
          expires_at: data.expires_at,
        });

        return {
          ...data,
          id: doc.id,
        };
      } else {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Either transactionId or donationId must be provided"
        );
      }
    } catch (error: any) {
      console.error("[getTransaction] Error:", error);
      throw error;
    }
  }
);
