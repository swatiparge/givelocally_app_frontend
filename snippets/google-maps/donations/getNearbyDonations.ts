/* eslint-disable max-len, @typescript-eslint/no-non-null-assertion */
/* eslint-disable require-jsdoc */
/* eslint-disable @typescript-eslint/no-explicit-any */


import * as functions from "firebase-functions";
import admin, {db} from "../config/firebase";
import {onCall, CallableRequest} from "firebase-functions/v2/https";


interface GetNearbyData {
    latitude: number;
    longitude: number;
    radiusKm: number; // 1,3,5,10
    category: string; // Optional filter
    limit?: number;
    startAfterDoc?: string; // For pagination
}

// Haversine distance formula
function haversineDistance(
  lat1: number, lon1: number,
  lat2: number, lon2: number,
): number {
  const R = 6371; // Earth radius in Km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Calculate bounding box
function getBoundingBox(lat: number, lon: number, radiusKm: number) {
  const latChange = radiusKm / 111.32; // 1° lat ≈ 111.32 km
  const lonChange = radiusKm / (111.32 * Math.cos(lat * Math.PI / 180));

  return {
    minLat: lat - latChange,
    maxLat: lat + latChange,
    minLon: lon - lonChange,
    maxLon: lon + lonChange,
  };
}


export const getNearbyDonations = onCall(
  {
    region: "asia-southeast1",
  },
  async (request: CallableRequest<GetNearbyData>)=> {
    // Authentication for public feed

    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be logged in"
      );
    }

    // Validation
    const data = request.data;
    if (!data.latitude || !data.longitude) {
      throw new functions.https.HttpsError("invalid-argument", "Location required");
    }

    if (!data.radiusKm || data.radiusKm < 1 || data.radiusKm > 50) {
      throw new functions.https.HttpsError("invalid-argument", "Radius must be 1-50 km");
    }

    const limit = data.limit && data.limit <= 20 ? data.limit : 10;

    // Bounding box : Coarse Filter
    const box = getBoundingBox(data.latitude, data.longitude, data.radiusKm);

    const minGeoPoint = new admin.firestore.GeoPoint(box.minLat, box.minLon);
    const maxGeoPoint = new admin.firestore.GeoPoint(box.maxLat, box.maxLon);

    // Firestore Query
    let query = db.collection("donations")
      .where("location", ">=", minGeoPoint)
      .where("location", "<=", maxGeoPoint)
      .where("status", "==", "active")
      .orderBy("location")
      .orderBy("created_at", "desc")
      .limit(limit * 2); // Get more for Haversine filtering

    // Category filter
    if (data.category && ["food", "appliances", "blood", "stationery"].includes(data.category)) {
      query = query.where("category", "==", data.category);
    }

    // Pagination
    if (data.startAfterDoc) {
      const startDoc = await db.collection("donations").doc(data.startAfterDoc).get();
      if (startDoc.exists) {
        query = query.startAfter(startDoc);
      }
    }

    const snapshot = await query.get();


    // Harversine distance
    const results: any[] = [];

    for (const doc of snapshot.docs) {
      const donation = doc.data();
      const distance = haversineDistance(
        data.latitude,
        data.longitude,
        donation.location.latitude,
        donation.location.longitude
      );

      if (distance <= data.radiusKm) {
        results.push({
          id: doc.id,
          ...donation,
          distance: Math.round(distance * 10) / 10, // Round to 1 decimal
        });
      }

      if (results.length >= limit) break;
    }

    // Sort by distance
    results.sort((a, b) => a.distance - b.distance);


    // Return response
    return {
      success: true,
      count: results.length,
      donations: results,
      hasMore: snapshot.size > results.length,
    };
  }
);
