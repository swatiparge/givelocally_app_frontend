/* eslint-disable max-len, @typescript-eslint/no-non-null-assertion  */
/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable require-jsdoc */
/* eslint-disable no-case-declarations */


import * as functions from "firebase-functions";
import {db} from "../config/firebase";
import {onCall, CallableRequest} from "firebase-functions/v2/https";
import {FieldValue} from "firebase-admin/firestore";


interface AcceptRequestData {
  donationId: string;
  requestId: string;
}

// Donor accepts a specific receiver
export const acceptRequest = onCall(
  {region: "asia-southeast1"},
  async (request: CallableRequest<AcceptRequestData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated", "Login required"
      );
    }

    const userId = request.auth.uid;
    const {donationId, requestId} = request.data;

    const donationRef = db.collection("donations").doc(donationId);
    const donationDoc = await donationRef.get();
    if (!donationDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found", "Donation not found"
      );
    }

    const donation = donationDoc.data()!;

    // Verify caller is donor
    if (donation.donorId !== userId) {
      throw new functions.https.HttpsError(
        "permission-denied", "Donor only"
      );
    }

    if (donation.status !== "active") {
      throw new functions.https.HttpsError(
        "failed-precondition", "Donation is no longer available"
      );
    }

    const requestDoc = await donationRef
      .collection("requests")
      .doc(requestId)
      .get();

    if (!requestDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found", "Request not found"
      );
    }


    // Mark request as accepted
    const requestData = requestDoc.data()!;
    await requestDoc.ref.update({
      status: "accepted",
      acceptedAt: FieldValue.serverTimestamp(),
    });

    // Set claimedBy on donation
    await donationRef.update({
      claimedBy: requestData.receiverId,
      claimedAt: FieldValue.serverTimestamp(),
    });

    // Reject other requests
    const allRequests = await donationRef
      .collection("requests")
      .where("status", "==", "pending")
      .get();

    const batch = db.batch();
    allRequests.docs.forEach((doc)=>{
      if (doc.id !== requestId) {
        batch.update(doc.ref, {
          status: "rejected",
          rejectedAt: FieldValue.serverTimestamp(),
        });
      }
    });
    await batch.commit();

    // TODO: Send FCM notifications
    // Accepted receiver: "Your request was accepted! Pay ₹50 to reserve."
    // Rejected receivers: "Donor chose someone else."

    // Send FCM to accepted receiver (ask for payment)
    // Send FCM to rejected requesters

    return {
      success: true,
      receiverId: requestData.receiverId,
      message: "Request accepted. Receiver will be notified to pay. ",
    };
  }
);
