/* eslint-disable max-len, @typescript-eslint/no-non-null-assertion  */
/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable require-jsdoc */
/* eslint-disable no-case-declarations */


import * as functions from "firebase-functions";
import {db} from "../config/firebase";
import {onCall, CallableRequest} from "firebase-functions/v2/https";


interface GetRequestsData {
  donationId: string;
}

//  Get requests for donor's donation
export const getDonationRequests = onCall(
  {region: "asia-southeast1"},
  async (request: CallableRequest<GetRequestsData>) => {
    // Validate user is not banned
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated", "Login required"
      );
    }

    const userId = request.auth.uid;
    const {donationId} = request.data;

    const donationDoc = await db.collection("donations").doc(donationId).get();

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

    // Return all requests with user profiles
    const requestsSnapshot = await db
      .collection("donations")
      .doc(donationId)
      .collection("requests")
      .orderBy("createdAt", "desc")
      .get();
    const requests = requestsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      success: true,
      count: requests.length,
      requests,
    };
  }
);

