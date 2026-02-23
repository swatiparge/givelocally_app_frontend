import axios from 'axios';
import crypto from 'crypto';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '../.env' });

const PROJECT_ID = 'givelocally-dev'; // Default for emulators
const REGION = 'asia-southeast1'; // Must match the region in your code
const FUNCTION_NAME = 'handleRazorpayWebhook';
const EMULATOR_HOST = 'https://0835dc25e66e.ngrok-free.app';
const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET || 'your_webhook_secret_here';

const WEBHOOK_URL = `${EMULATOR_HOST}/${PROJECT_ID}/${REGION}/${FUNCTION_NAME}`;

// Simulate a Payment Authorized Event
const payload = {
  "entity": "event",
  "account_id": "acc_test_123",
  "event": "payment.authorized",
  "contains": [
    "payment"
  ],
  "payload": {
    "payment": {
      "entity": {
        "id": "pay_" + Math.random().toString(36).substring(7), // Random Payment ID
        "entity": "payment",
        "amount": 5000,
        "currency": "INR",
        "status": "authorized",
        "order_id": "order_SC97sj2BO7k3VS", // "order_" + Math.random().toString(36).substring(7), // Random Order ID
        "invoice_id": null,
        "international": false,
        "method": "upi",
        "amount_refunded": 0,
        "refund_status": null,
        "captured": false,
        "description": "Promise Fee",
        "card_id": null,
        "bank": null,
        "wallet": null,
        "vpa": "test@upi",
        "email": "test@example.com",
        "contact": "+919876543210",
        "notes": {
          "donationId": "test_donation_123",
          "receiverId": "test_receiver_456",
          "donorId": "test_donor_789",
          "type": "promise_fee"
        },
        "fee": 0,
        "tax": 0,
        "error_code": null,
        "error_description": null,
        "created_at": Math.floor(Date.now() / 1000)
      }
    }
  },
  "created_at": Math.floor(Date.now() / 1000)
};

const payloadString = JSON.stringify(payload);

// Calculate Signature
const signature = crypto
  .createHmac('sha256', WEBHOOK_SECRET)
  .update(payloadString)
  .digest('hex');

console.log(`Sending Webhook to: ${WEBHOOK_URL}`);
console.log(`Payment ID: ${payload.payload.payment.entity.id}`);
console.log(`Order ID: ${payload.payload.payment.entity.order_id}`);

async function sendWebhook() {
  try {
    const response = await axios.post(WEBHOOK_URL, payload, {
      headers: {
        'Content-Type': 'application/json',
        'x-razorpay-signature': signature
      }
    });

    console.log('✅ Webhook sent successfully!');
    console.log('Status:', response.status);
    console.log('Response:', response.data);
  } catch (error: any) {
    console.error('❌ Failed to send webhook');
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Data:', error.response.data);
    } else {
      console.error(error.message);
    }
  }
}

sendWebhook();
