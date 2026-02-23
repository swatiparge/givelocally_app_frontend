/* eslint-disable max-len, @typescript-eslint/no-non-null-assertion */
/* eslint-disable require-jsdoc */

import * as functions from "firebase-functions";
import {db} from "../config/firebase";
import {onCall, CallableRequest} from "firebase-functions/v2/https";
import {FieldValue} from "firebase-admin/firestore";


interface UpdateStatusData {
    donationId: string;
    newStatus: "active" | "expired" | "completed"
    reason?: string;
}

export const updateDonationStatus = onCall(
  {
    region: "asia-southeast1",
  },

  async (request: CallableRequest<UpdateStatusData>) =>{
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Login required"
      );
    }

    const data = request.data;
    const donationRef = db.collection("donations").doc(data.donationId);
    const donationSnap = await donationRef.get();

    if (!donationSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Donation not found"
      );
    }

    const donation = donationSnap.data()!;

    // Only donor can update status
    if (donation.donorId !== request.auth.uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Donor only"
      );
    }

    // Valid transitions
    const validTransitions: Record<string, string[]> = {
      active: ["expired"],
      reserved: [], // Cannot manually change (system changed)
      completed: [],
      expired: ["active"], // Relist
    };

    if (!validTransitions[donation.status]?.includes(data.newStatus)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Cannot change from ${donation.status} to ${data.newStatus}`
      );
    }

    await donationRef.update({
      status: data.newStatus,
      update_at: FieldValue.serverTimestamp(),
    });

    return {success: true, message: "Status updated"};
  }
);
