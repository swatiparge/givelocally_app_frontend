// /* eslint-disable max-len, @typescript-eslint/no-non-null-assertion  */
// /* eslint-disable @typescript-eslint/no-explicit-any */
// /* eslint-disable require-jsdoc */
// /* eslint-disable no-case-declarations */


import * as functions from "firebase-functions";
import {db} from "../config/firebase";
import {onCall, CallableRequest} from "firebase-functions/v2/https";
import {FieldValue} from "firebase-admin/firestore";


interface CreateRequestData {
    donationId: string;
    message?: string;
}


export const createRequest = onCall(
  {
    region: "asia-southeast1",
  },
  async (request: CallableRequest<CreateRequestData>) => {
    // Validate user is not banned
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated", "Login required"
      );
    }

    const userId = request.auth.uid;
    const {donationId, message} = request.data;

    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found", "User not found"
      );
    }
    const userData = userDoc.data()!;
    if (userData.is_banned) {
      throw new functions.https.HttpsError(
        "permission-denied", `Account banned ${userData.ban_reason || "Policy Violation"}`
      );
    }

    // Check donation is active
    const donationRef = db.collection("donations").doc(donationId);
    const donationDoc = await donationRef.get();
    if (!donationDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found", "Donation not found"
      );
    }

    const donation = donationDoc.data()!;

    if (donation.status !== "active") {
      throw new functions.https.HttpsError(
        "failed-precondition", "Donation is no longer available"
      );
    }

    if (donation.donorId === userId) {
      throw new functions.https.HttpsError(
        "invalid-argument", "Cannot request your own donation"
      );
    }

    const existingRequest = await donationRef
      .collection("requests")
      .where("receiverId", "==", userId)
      .get();
    if (!existingRequest.empty) {
      throw new functions.https.HttpsError(
        "already-exists", "You already requested this donation"
      );
    }

    // Create request document under donations/{donationId}/requests/{requestId}
    const requestRef = await donationRef.collection("requests").add({
      receiverId: userId,
      receiverName: userData.name || "Anonymous",
      receiverPhone: userData.phone,
      receiverTrustScore: userData.trust_score || 50,
      message: message || "",
      status: "pending", // pending, accepted, rejected
      createdAt: FieldValue.serverTimestamp(),
    });

    await donationRef.update({
      chat_requests: FieldValue.increment(1),
    });

    // TODO: Send FCM to donor
    // await sendNotification(donation.donorId, {
    //     title :"New Request",
    //     body: `${userData.name} wants your ${donation.title}`,
    // });

    // Return requestId
    return {
      success: true,
      requestId: requestRef.id,
      message: "Request sent to donor",
    };
  }
);
