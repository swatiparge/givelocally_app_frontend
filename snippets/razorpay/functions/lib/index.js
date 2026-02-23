"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkExpiredAuthorizations = exports.verifyPickupCode = exports.handleRazorpayWebhook = exports.createPaymentOrder = void 0;
const functions = __importStar(require("firebase-functions"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin = __importStar(require("firebase-admin"));
const razorpay_1 = __importDefault(require("razorpay"));
const crypto_1 = __importDefault(require("crypto"));
const firestore_1 = require("firebase-admin/firestore");
// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();
// ==================== HELPER FUNCTIONS ====================
/**
 * Generate a 4-digit pickup code
 */
function generatePickupCode() {
    return Math.floor(1000 + Math.random() * 9000).toString();
}
/**
 * Verify webhook signature
 */
function verifyWebhookSignature(webhookBody, webhookSignature, webhookSecret) {
    const expectedSignature = crypto_1.default
        .createHmac("sha256", webhookSecret)
        .update(webhookBody)
        .digest("hex");
    return expectedSignature === webhookSignature;
}
// ==================== CLOUD FUNCTIONS ====================
/**
 * Cloud Function: createPaymentOrder
 * Creates a Razorpay order with payment_capture: 0 (Authorization Only)
 * Trigger: Receiver clicks "Pay ₹50"
 */
exports.createPaymentOrder = functions.https.onCall({
    region: 'asia-southeast1',
}, async (request) => {
    // 1. Authentication Check
    // if (!request.auth) {
    //   throw new functions.https.HttpsError("unauthenticated", "Login required");
    // }
    // Initialize Razorpay
    // Note: In production, use firebase-functions:secrets instead of process.env
    const razorpay = new razorpay_1.default({
        key_id: process.env.RAZORPAY_KEY_ID || "",
        key_secret: process.env.RAZORPAY_KEY_SECRET || "",
    });
    // const userId = request.auth.uid;
    const userId = "test_receiver_456";
    const { donationId, idempotencyKey } = request.data;
    // 2. Idempotency Check (Prevent double charges)
    const idempotencyRef = db.collection("idempotencyKeys").doc(idempotencyKey);
    const idempotencyDoc = await idempotencyRef.get();
    if (idempotencyDoc.exists) {
        const existingData = idempotencyDoc.data();
        return {
            success: true,
            orderId: existingData?.orderId,
            amount: existingData?.amount,
            currency: existingData?.currency,
            existing: true,
        };
    }
    // // 3. Validate Donation Status
    // const donationRef = db.collection("donations").doc(donationId);
    // const donationDoc = await donationRef.get();
    // if (!donationDoc.exists) {
    //   throw new functions.https.HttpsError("not-found", "Donation not found");
    // }
    // const donation = donationDoc.data();
    // if (donation?.status !== "active") {
    //   throw new functions.https.HttpsError(
    //     "failed-precondition",
    //     "Donation is no longer available"
    //   );
    // }
    // // Ensure the caller is the one who claimed it
    // if (donation?.claimed_by && donation.claimed_by !== userId) {
    //   throw new functions.https.HttpsError(
    //     "permission-denied",
    //     "Item claimed by another user"
    //   );
    // }
    // 4. Create Razorpay Order
    // Amount is fixed at ₹50.00 (5000 paise)
    const orderAmount = 5000;
    try {
        const razorpayOrder = await razorpay.orders.create({
            amount: orderAmount,
            currency: "INR",
            payment_capture: false, // CRITICAL: 0 = Auth Only (Manual Capture)
            receipt: idempotencyKey.substring(0, 40), // Receipt ID
            notes: {
                donationId: donationId,
                receiverId: userId,
                donorId: "test_donation_123", // donation?.donorId,
                type: "promise_fee",
            },
        });
        // 5. Save Idempotency Record
        // Expires in 24 hours
        const expiresAt = new Date();
        expiresAt.setHours(expiresAt.getHours() + 24);
        await idempotencyRef.set({
            orderId: razorpayOrder.id,
            donationId: donationId,
            userId: userId,
            amount: orderAmount,
            currency: "INR",
            status: "created",
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            expiresAt: firestore_1.Timestamp.fromDate(expiresAt),
        });
        return {
            success: true,
            orderId: razorpayOrder.id,
            amount: orderAmount,
            currency: "INR",
        };
    }
    catch (error) {
        console.error("Razorpay Order Creation Failed:", error);
        throw new functions.https.HttpsError("internal", "Payment initialization failed");
    }
});
/**
 * Cloud Function: handleRazorpayWebhook
 * Handles Razorpay webhook events
 * Trigger: Razorpay server sends payment.authorized event
 */
exports.handleRazorpayWebhook = functions.https.onRequest({
    region: 'asia-southeast1',
}, async (req, res) => {
    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;
    const webhookSignature = req.get("x-razorpay-signature");
    const webhookBody = req.rawBody?.toString() || "";
    // 1. Verify Signature
    if (!verifyWebhookSignature(webhookBody, webhookSignature, webhookSecret)) {
        console.error("Webhook signature verification failed");
        res.status(401).send("Invalid signature");
        return;
    }
    // 2. Parse Event
    let event;
    try {
        event = JSON.parse(webhookBody);
    }
    catch (error) {
        console.error("Failed to parse webhook body:", error);
        res.status(400).send("Invalid payload");
        return;
    }
    // 3. Handle Events
    try {
        switch (event.event) {
            case "payment.authorized":
                await handlePaymentAuthorized(event.payload.payment.entity);
                break;
            case "payment.captured":
                await handlePaymentCaptured(event.payload.payment.entity);
                break;
            case "payment.refunded":
                await handlePaymentRefunded(event.payload.payment.entity);
                break;
            default:
                console.log(`Unhandled event: ${event.event}`);
        }
        res.status(200).send("OK");
    }
    catch (error) {
        console.error("Error processing webhook:", error);
        res.status(500).send("Internal error");
    }
});
/**
 * Helper: Handle Payment Authorized
 */
async function handlePaymentAuthorized(payment) {
    const orderId = payment.order_id;
    const paymentId = payment.id;
    const receiverId = payment.notes?.receiverId;
    const donationId = payment.notes?.donationId;
    const donorId = payment.notes?.donorId;
    if (!donationId || !receiverId || !donorId) {
        console.error("Missing required notes in payment");
        return;
    }
    // 4-digit pickup code
    const pickupCode = generatePickupCode();
    const pickupCodeExpires = new Date();
    pickupCodeExpires.setHours(pickupCodeExpires.getHours() + 24);
    await db.runTransaction(async (transaction) => {
        const donationRef = db.collection("donations").doc(donationId);
        const transactionRef = db.collection("transactions").doc(paymentId);
        const donationDoc = await transaction.get(donationRef);
        if (!donationDoc.exists) {
            throw new Error("Donation not found");
        }
        // Create Transaction Record
        transaction.set(transactionRef, {
            donationId: donationId,
            donorId: donorId,
            receiverId: receiverId,
            promise_fee: 50,
            payment_status: "authorized",
            razorpay_payment_id: paymentId,
            razorpay_order_id: orderId,
            pickup_code: pickupCode,
            pickup_code_expires: firestore_1.Timestamp.fromDate(pickupCodeExpires),
            pickup_code_used: false,
            authorization_expires: firestore_1.Timestamp.fromDate(pickupCodeExpires),
            created_at: firestore_1.FieldValue.serverTimestamp(),
            expires_at: firestore_1.Timestamp.fromDate(pickupCodeExpires),
        });
        // Update Donation Status
        transaction.update(donationRef, {
            status: "reserved",
            claimed_by: receiverId,
            address_visible: true,
            reserved_at: firestore_1.FieldValue.serverTimestamp(),
        });
    });
    // Send Notification (TODO: Implement FCM)
    console.log(`Payment authorized for ${donationId}, pickup code: ${pickupCode}`);
}
/**
 * Helper: Handle Payment Captured (Forfeit)
 */
async function handlePaymentCaptured(payment) {
    const paymentId = payment.id;
    const transactionRef = db.collection("transactions").doc(paymentId);
    await transactionRef.update({
        payment_status: "captured",
        captured_at: firestore_1.FieldValue.serverTimestamp(),
    });
    console.log(`Payment forfeited: ${paymentId}`);
}
/**
 * Helper: Handle Payment Refunded (Void)
 */
async function handlePaymentRefunded(payment) {
    const paymentId = payment.id;
    const transactionRef = db.collection("transactions").doc(paymentId);
    await transactionRef.update({
        payment_status: "cancelled",
        refunded_at: firestore_1.FieldValue.serverTimestamp(),
    });
    console.log(`Payment refunded: ${paymentId}`);
}
/**
 * Cloud Function: verifyPickupCode
 * Verifies the 4-digit pickup code and voids the authorization
 * Trigger: Donor enters pickup code
 */
exports.verifyPickupCode = functions.https.onCall({
    region: 'asia-southeast1',
}, async (request) => {
    // if (!request.auth) {
    //   throw new functions.https.HttpsError("unauthenticated", "Login required");
    // }
    // Initialize Razorpay
    // Note: In production, use firebase-functions:secrets instead of process.env
    const razorpay = new razorpay_1.default({
        key_id: process.env.RAZORPAY_KEY_ID || "",
        key_secret: process.env.RAZORPAY_KEY_SECRET || "",
    });
    const userId = 'test_donation_123'; // request.auth.uid;
    const { donationId, pickupCode } = request.data;
    // 1. Find the transaction for this donation
    const transactionsSnapshot = await db
        .collection("transactions")
        .where("donationId", "==", donationId)
        .where("donorId", "==", userId)
        .where("payment_status", "==", "authorized")
        .get();
    if (transactionsSnapshot.empty) {
        throw new functions.https.HttpsError("not-found", "No active transaction found");
    }
    const transactionDoc = transactionsSnapshot.docs[0];
    const transaction = transactionDoc.data();
    const transactionId = transactionDoc.id;
    // 2. Validate Pickup Code
    if (transaction.pickup_code !== pickupCode) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid pickup code");
    }
    // 3. Check Expiry
    const now = new Date();
    const expiresAt = transaction.pickup_code_expires?.toDate();
    if (expiresAt && now > expiresAt) {
        throw new functions.https.HttpsError("failed-precondition", "Pickup code has expired");
    }
    // 4. Check if already used
    if (transaction.pickup_code_used) {
        throw new functions.https.HttpsError("already-exists", "Pickup code already used");
    }
    try {
        const payment = await razorpay.payments.fetch(transactionId);
        if (payment.status === "authorized") {
            // Capture the payment 
            await razorpay.payments.capture(transactionId, transaction.promise_fee * 100, "INR");
            // Void the authorization so the blocked amount is released to donor
            // 5. Refund/Void the Authorization
            await razorpay.payments.refund(transactionId, {
                amount: transaction.promise_fee * 100, // Convert ₹50 to paise
                speed: "normal",
            });
        }
        else if (payment.status === "captured") {
            // If by some race condition if it was already captured, refund it
            await razorpay.payments.refund(transactionId, {
                amount: transaction.promise_fee * 100,
            });
        }
        // 6. Update Transaction and Donation
        const batch = db.batch();
        batch.update(db.collection("transactions").doc(transactionId), {
            payment_status: "voided",
            pickup_code_used: true,
            pickup_completed_at: firestore_1.FieldValue.serverTimestamp(),
        });
        batch.update(db.collection("donations").doc(donationId), {
            status: "completed",
            completed_at: firestore_1.FieldValue.serverTimestamp(),
        });
        await batch.commit();
        // 7. Award Karma (TODO: Implement)
        console.log(`Pickup completed for ${donationId} by ${userId}`);
        return {
            success: true,
            message: "Pickup verified successfully",
        };
    }
    catch (error) {
        console.error("Error verifying pickup code:", error);
        throw new functions.https.HttpsError("internal", error.description || "Failed to verify pickup code");
    }
});
/**
 * Cloud Function: checkExpiredAuthorizations
 * Scheduled function to check for expired authorizations and capture forfeit fees
 * Trigger: Runs every 10 minutes
 */
exports.checkExpiredAuthorizations = (0, scheduler_1.onSchedule)({
    timeZone: "Asia/Kolkata",
    schedule: "*/1 * * * *",
    region: 'asia-southeast1',
    // You can also set memory, timeout etc..
}, async (event) => {
    // Initialize Razorpay
    // Note: In production, use firebase-functions:secrets instead of process.env
    const razorpay = new razorpay_1.default({
        key_id: process.env.RAZORPAY_KEY_ID || "",
        key_secret: process.env.RAZORPAY_KEY_SECRET || "",
    });
    const now = firestore_1.Timestamp.now();
    // Query expired transactions
    const expiredTransactions = await db
        .collection("transactions")
        .where("payment_status", "==", "authorized")
        .where("expires_at", "<", now)
        .where("pickup_code_used", "==", false)
        .get();
    console.log(`Found ${expiredTransactions.size} expired transactions`);
    for (const doc of expiredTransactions.docs) {
        const transaction = doc.data();
        const paymentId = doc.id;
        const donationId = transaction.donationId;
        try {
            // Attempt to capture the payment
            await razorpay.payments.capture(paymentId, transaction.promise_fee * 100, "INR");
            // Update transaction status
            await doc.ref.update({
                payment_status: "captured",
                captured_at: firestore_1.FieldValue.serverTimestamp(),
            });
            // Relist the donation
            await db.collection("donations").doc(donationId).update({
                status: "active",
                claimed_by: null,
                address_visible: false,
            });
            // Apply penalty (TODO: Implement)
            console.log(`Forfeited payment captured: ${paymentId}`);
        }
        catch (error) {
            console.error(`Failed to capture forfeit for ${paymentId}:`, error);
            // If authorization expired, mark as expired
            if (error.error?.code === "BAD_REQUEST_ERROR") {
                await doc.ref.update({
                    payment_status: "expired",
                });
            }
        }
    }
});
//# sourceMappingURL=index.js.map