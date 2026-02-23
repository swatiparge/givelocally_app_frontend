import * as functions from "firebase-functions";
import {onCall, CallableRequest} from "firebase-functions/v2/https";
import {db} from "./config";

interface GeocodeRequest {
  address?: string;
  lat?: number;
  lng?: number;
}

const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

export const geocodeAddress = onCall(
  {region: "asia-southeast1", secrets: ["GOOGLE_MAPS_API_KEY"]},
  async (request: CallableRequest<GeocodeRequest>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
    }

    const {address, lat, lng} = request.data;
    
    // Create a cache key
    let cacheKey = "";
    let googleUrl = "";

    if (address) {
      const cleanAddress = address.trim().toLowerCase();
      cacheKey = `addr_${cleanAddress.replace(/\s+/g, "_")}`;
      googleUrl = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${GOOGLE_MAPS_API_KEY}`;
    } else if (lat && lng) {
      // Round to ~11 meters precision for caching
      const rLat = Math.round(lat * 10000) / 10000;
      const rLng = Math.round(lng * 10000) / 10000;
      cacheKey = `loc_${rLat}_${rLng}`;
      googleUrl = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${GOOGLE_MAPS_API_KEY}`;
    } else {
      throw new functions.https.HttpsError("invalid-argument", "Address or Lat/Lng required");
    }

    // 1. Check Cache
    const cacheDoc = await db.collection("geo_cache").doc(cacheKey).get();
    if (cacheDoc.exists) {
      return {source: "cache", ...cacheDoc.data()};
    }

    // 2. Call Google API
    try {
      const response = await fetch(googleUrl);
      const data = await response.json();

      if (data.status !== "OK") {
        throw new functions.https.HttpsError("internal", `Google API Error: ${data.status}`);
      }

      const result = data.results[0];
      const formattedAddress = result.formatted_address;
      const location = result.geometry.location;

      const payload = {
        formatted_address: formattedAddress,
        lat: location.lat,
        lng: location.lng,
        place_id: result.place_id,
        updated_at: new Date().toISOString(),
      };

      // 3. Save to Cache
      await db.collection("geo_cache").doc(cacheKey).set(payload);

      return {source: "google", ...payload};
    } catch (error) {
      throw new functions.https.HttpsError("internal", "Failed to fetch from Google Maps");
    }
  }
);
