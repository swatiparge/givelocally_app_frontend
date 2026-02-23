import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {onCall, CallableRequest} from "firebase-functions/v2/https";
import {db} from "./config";

interface NearbySearchRequest {
  latitude: number;
  longitude: number;
  radiusKm: number;
  collection: string; // e.g., "donations", "stores"
  category?: string;
  limit?: number;
}

// Haversine formula
function haversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function getBoundingBox(lat: number, lon: number, radiusKm: number) {
  const latChange = radiusKm / 111.32;
  const lonChange = radiusKm / (111.32 * Math.cos(lat * Math.PI / 180));
  return {
    minLat: lat - latChange,
    maxLat: lat + latChange,
    minLon: lon - lonChange,
    maxLon: lon + lonChange,
  };
}

export const nearbySearch = onCall(
  {region: "asia-southeast1"},
  async (request: CallableRequest<NearbySearchRequest>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
    }

    const {latitude, longitude, radiusKm, collection, category, limit = 20} = request.data;

    if (!latitude || !longitude || !collection) {
      throw new functions.https.HttpsError("invalid-argument", "Missing lat/lng or collection");
    }

    // 1. Calculate Bounding Box
    const box = getBoundingBox(latitude, longitude, radiusKm);
    const minGeoPoint = new admin.firestore.GeoPoint(box.minLat, box.minLon);
    const maxGeoPoint = new admin.firestore.GeoPoint(box.maxLat, box.maxLon);

    // 2. Query Firestore
    let query = db.collection(collection)
      .where("location", ">=", minGeoPoint)
      .where("location", "<=", maxGeoPoint);
      
    // Note: status check is specific to "donations", so we might need to remove it 
    // or make it a param if we want true genericness. 
    // For now, I'll assume the client filters status or we assume all active docs are valid.
    // If "donations", let's filter active.
    if (collection === "donations") {
        query = query.where("status", "==", "active");
    }

    if (category) {
      query = query.where("category", "==", category);
    }

    const snapshot = await query.limit(limit * 2).get(); // Fetch extra for filtering

    // 3. Filter by Exact Distance
    const results: any[] = [];
    for (const doc of snapshot.docs) {
      const data = doc.data();
      // Ensure data has location
      if (!data.location || !data.location.latitude) continue;

      const dist = haversineDistance(
        latitude, 
        longitude, 
        data.location.latitude, 
        data.location.longitude
      );

      if (dist <= radiusKm) {
        results.push({
          id: doc.id,
          ...data,
          distance: parseFloat(dist.toFixed(1)),
        });
      }
    }

    // 4. Sort
    results.sort((a, b) => a.distance - b.distance);

    return {
      results: results.slice(0, limit),
      count: results.length
    };
  }
);
