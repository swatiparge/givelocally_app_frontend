/* eslint-disable max-len, @typescript-eslint/no-non-null-assertion  */
/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable require-jsdoc */
/* eslint-disable no-case-declarations */


import * as functions from "firebase-functions";
import admin, {db} from "../config/firebase";
import {onCall, CallableRequest} from "firebase-functions/v2/https";
import {Timestamp, FieldValue, GeoPoint} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";


interface CreateDonationData {
    category: "food" | "appliances" | "blood" | "stationery";
    title: string;
    description:string;
    images: string[]; // Storage URLS
    condition: "new" | "good" | "fair";
    location: admin.firestore.GeoPoint;
    address: string;
    pickup_instructions?: string;
    pickup_window: {
        start_date : admin.firestore.Timestamp;
        end_date: admin.firestore.Timestamp;
    };


    // Category-specific fields (optional, validated per category)
    food_quantity?: number;
    food_unit?: string;
    expiry_date: admin.firestore.Timestamp;
    dietary_tags?:string[];
    storage_required?: boolean;


    subcategory? : string;
    brand?: string;
    purchase_year?: number;
    working_condition?:string;
    dimensions?: { length: number, width: number, height:number};
    is_heavy?: boolean;

    blood_type?: string;
    units_needed?: number;
    urgency?:string;
    hospital_name?:string;
    hospital_contact?:string;
    hospital_address?: string;
    proof_document?: string;


    stationery_type?: string;
    board?: string;
    subjects?: string;
    quantity?: number;
    marking_level?: string;
}


export const createDonation = onCall(
  {
    region: "asia-southeast1",
  },

  async (request: CallableRequest<CreateDonationData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be logged in to create donation"
      );
    }


    const userId = request.auth.uid;
    logger.info("CreateDonation called", {uid: userId});


    // Check if user is banned
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "User not found"
      );
    }

    const userData = userDoc.data();
    if (userData!.is_banned) {
      throw new functions.https.HttpsError(
        "permission-denied",
        `Account denied: ${userData!.ban_reason || " Policy violation"}`
      );
    }

    // Rate limiting - Max % active donations per user

    const activeDonation = await db.collection("donations")
      .where("donorId", "==", userId)
      .where("status", "==", "active")
      .get();

    if (activeDonation.size >=5) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Maximum 5 active donations allowes. Complete or expire existing ones."
      );
    }

    // Validation

    const errors: string[] = [];

    const data = request.data;
    if (!data.title || data.title.length < 10 || data.title.length > 100) {
      errors.push("Title must be 10-100 characters");
    }

    if (!data.description || data.description.length < 20 ||
        data.description.length > 500) {
      errors.push("Description must be 20-500 characters");
    }

    if (!data.images || data.images.length === 0 || data.images.length > 3) {
      errors.push("Must provide 1-3 images");
    }


    if (!["new", "good", "fair"].includes(data.condition)) {
      errors.push("Invalid condition");
    }

    if (!data.location) {
      errors.push("Valid location required");
    } else {
      try {
        toGeoPoint(data.location);
      } catch (e) {
        errors.push("Valid location required");
      }
    }

    if (!data.address || data.address.length < 10) {
      errors.push("Valid address required");
    }

    // Category Specific

    switch (data.category) {
    case "food":
      if (!data.food_quantity || data.food_quantity < 1) {
        errors.push("Food quantity must be ≥1");
      }
      if (!data.food_unit || !["servings", "kg"].includes(data.food_unit)) {
        errors.push("Food unit must be \"servings\" or \"kg\"");
      }
      if (!data.expiry_date) {
        errors.push("Expiry date required for food");
      } else {
        const expiryTimeStamp = convertToTimestamp(data.expiry_date);
        const expiryMs = expiryTimeStamp.toMillis();
        const twoHoursFromNow = Date.now() + (2 * 60 * 60 * 1000);
        if (expiryMs < twoHoursFromNow) {
          errors.push("Food expiry must be at least 2 hours from now");
        }
      }

      // Food pickup window max 12 Hours
      const startTimestamp = convertToTimestamp(data.pickup_window.start_date);
      const endTimestamp = convertToTimestamp(data.pickup_window.end_date);
      const foodWindows = startTimestamp.toMillis() -
                                endTimestamp.toMillis();
      if (foodWindows > 12 * 60 * 60 * 1000 ) {
        errors.push("Food pickup window cannot exceed 12 hours");
      }
      break;

    case "appliances":
      if (!data.subcategory || !["furniture", "electronics", "kitchen"]
        .includes(data.subcategory)) {
        errors.push("Invalid appliance subcategory");
      }
      if (!data.working_condition || !["fully_functional", "minor_issues"]
        .includes(data.working_condition)) {
        errors.push("Invalid working condition");
      }
      break;

    case "blood":
      const validBloodTypes = ["O+", "A+", "B+", "AB+", "O-", "A-", "B-", "AB-"];
      if (!data.blood_type || !validBloodTypes.includes(data.blood_type)) {
        errors.push("Invalid blood type");
      }
      if (!data.units_needed || data.units_needed < 1 || data.units_needed > 10) {
        errors.push("Blood units must be 1-10");
      }
      if (!data.urgency || !["critical", "standard"].includes(data.urgency)) {
        errors.push("Invalid urgency level");
      }
      if (!data.hospital_name || data.hospital_name.length < 5) {
        errors.push("Valid hospital name required");
      }
      if (!data.hospital_contact || !/^\+91[6-9]\d{9}$/.test(data.hospital_contact)) {
        errors.push("Valid hospital contact required");
      }
      if (!data.proof_document) {
        errors.push("Proof document required for blood requests");
      }
      break;

    case "stationery":
      if (!data.stationery_type || !["books", "notebooks", "supplies"].includes(data.stationery_type)) {
        errors.push("Invalid stationery type");
      }
      if (!data.quantity || data.quantity < 1) {
        errors.push("Quantity must be ≥1");
      }
      break;

    default:
      errors.push("invalid category");
    }

    if (errors.length>0) {
      throw new functions.https.HttpsError(
        "invalid-argument", errors.join("; ") );
    }


    // Blood donation - Auto verify or pending

    let verificationStatus = "approved";
    if (data.category == "blood") {
      const trustScore = userData!.trust_score || 50;

      if (trustScore < 60) {
        // New/ low -trust users need admin approval
        verificationStatus ="pending";
      } else {
        // Trusted user auto-approved
        verificationStatus = "approved";
      }
    }

    // Create donation document

    const now = Timestamp.now();
    const expiresAt = Timestamp.fromMillis(
      now.toMillis() + (30 * 24 * 60 * 60 * 1000) // 30 days
    );

    const donationData: any = {

      // Core fields
      donorId: userId,
      category: data.category,
      title: data.title,
      description: data.description,
      images: data.images,
      condition: data.condition,

      // Location
      location: toGeoPoint(data.location),
      address: data.address,
      address_visible: false, // Hidden until payment
      pickup_instructions: data.pickup_instructions || "",

      // Pickup window
      pickup_window: {
        start_date: convertToTimestamp(data.pickup_window.start_date),
        end_time: convertToTimestamp(data.pickup_window.end_date),
      },

      // Status
      status: verificationStatus === "approved" ? "active" : "pending",
      claimed_by: null,
      promise_fee: 50,

      // Timestamps
      created_at: now,
      reserved_at: null,
      completed_at: null,
      expires_at: expiresAt,

      // Metrics
      views: 0,
      chat_requests: 0,

    };

    // Add category-specific fields
    if (data.category === "food") {
      donationData.food_quantity = data.food_quantity;
      donationData.food_unit = data.food_unit;
      donationData.expiry_date = convertToTimestamp(data.expiry_date);
      donationData.dietary_tags = data.dietary_tags || [];
      donationData.storage_required = data.storage_required || false;
    }

    if (data.category === "appliances") {
      donationData.subcategory = data.subcategory;
      donationData.brand = data.brand || null;
      donationData.purchase_year = data.purchase_year || null;
      donationData.working_condition = data.working_condition;
      donationData.dimensions = data.dimensions || null;
      donationData.is_heavy = data.is_heavy || false;
    }

    if (data.category === "blood") {
      donationData.blood_type = data.blood_type;
      donationData.units_needed = data.units_needed;
      donationData.urgency = data.urgency;
      donationData.hospital_name = data.hospital_name;
      donationData.hospital_contact = data.hospital_contact;
      donationData.hospital_address = data.hospital_address;
      donationData.proof_document = data.proof_document;
      donationData.verification_status = verificationStatus;
      donationData.verified_by = verificationStatus === "approved" ? "auto" : null;
      donationData.verified_at = verificationStatus === "approved" ? now : null;
      donationData.rejection_reason = null;
    }

    if (data.category === "stationery") {
      donationData.stationery_type = data.stationery_type;
      donationData.board = data.board || null;
      donationData.subjects = data.subjects || [];
      donationData.quantity = data.quantity;
      donationData.marking_level = data.marking_level || "minimal";
    }

    // Save to firestore
    const donationRef = await db.collection("donations").add(donationData);


    // Update user stats
    await db.collection("users").doc(userId).update({
      total_donations: FieldValue.increment(1),
      last_active: now,
    });

    // Return response

    return {
      success: true,
      donationId: donationRef.id,
      status: donationData.status,
      verification_status: verificationStatus,
      message: verificationStatus === "pending" ?
        "Blood request submitted for admin approval" :
        "Donation created successfully",
    };
  }
);


function convertToTimestamp(data: any): admin.firestore.Timestamp {
  if (data instanceof admin.firestore.Timestamp) {
    return data; // Already a Timestamp
  }

  if (data && typeof data === "object") {
    // Handle {_seconds, _nanoseconds} format from client
    if ("_seconds" in data) {
      return admin.firestore.Timestamp.fromMillis(data._seconds * 1000);
    }
    // Handle {seconds, nanoseconds} format
    if ("seconds" in data) {
      return new admin.firestore.Timestamp(data.seconds, data.nanoseconds || 0);
    }
  }

  throw new Error("Invalid timestamp format");
}


// Add this helper function alongside your toTimestamp helper
function toGeoPoint(obj: any): GeoPoint {
  if (obj instanceof GeoPoint) {
    return obj;
  }
  if (obj && typeof obj === "object") {
    // Handle both formats: {latitude, longitude} and {_latitude, _longitude}
    const lat = obj.latitude ?? obj._latitude;
    const lng = obj.longitude ?? obj._longitude;

    if (lat !== undefined && lng !== undefined) {
      return new GeoPoint(lat, lng);
    }
  }
  throw new Error("Invalid GeoPoint format");
}
