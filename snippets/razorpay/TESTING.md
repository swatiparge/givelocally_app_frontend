# Testing Guide - Razorpay Promise Fee Flow

This guide walks you through testing the complete payment flow locally.

## Prerequisites

- [ ] Firebase emulators running
- [ ] Flutter app running (web or mobile)
- [ ] Razorpay Test Key configured in `.env`

## Test Scenario: Complete Donation Flow

### Setup Test Data

1. **Create a test donation** (via Firestore Emulator UI or manually):
   ```javascript
   // In Firestore at http://localhost:4000/firestore
   Collection: donations
   Document ID: test_donation_123
   {
     "status": "active",
     "donorId": "test_donor_789",
     "title": "Test Item",
     "claimed_by": "test_receiver_456",
     "address": "123 Test Street, Hyderabad"
   }
   ```

### Flow 1: Successful Pickup (Happy Path)

#### Step 1: Receiver Pays Promise Fee

1. Open the Flutter app
2. Navigate to: **"Razorpay Flow Test"**
3. Click: **"1. Receiver: Pay Promise Fee"**
4. You should see the **"Reserve Item"** screen with ₹50
5. Click **"PAY ₹50"**
6. **Razorpay Checkout** opens

**Use Test Card:**
```
Card Number: 5267 3181 8797 5449
Expiry: 12/25
CVV: 123
Name: Test User
```

7. Complete the payment
8. You should see: **"Payment Authorized"** dialog

**Expected Result:**
- ✅ Razorpay order created
- ✅ Payment authorized (not captured)
- ✅ Backend receives webhook (via simulation)

#### Step 2: Simulate Webhook (Backend Processing)

In a new terminal:

```bash
cd functions/scripts
npx ts-node simulate_webhook.ts
```

**Expected Output:**
```
Sending Webhook to: http://127.0.0.1:5001/...
Payment ID: pay_xxxxxxxx
Order ID: order_xxxxxxxx
✅ Webhook sent successfully!
Status: 200
```

**What Happens:**
- Transaction record created in Firestore
- Pickup code generated (4 digits)
- Donation status changed to "reserved"

#### Step 3: Verify Transaction Created

Check Firestore at: http://localhost:4000/firestore

```
Collection: transactions
Document: pay_xxxxxxxx
{
  "donationId": "test_donation_123",
  "payment_status": "authorized",
  "pickup_code": "7382",  // Your 4-digit code
  "pickup_code_expires": "2024-...",
  "promise_fee": 50
}
```

#### Step 4: Receiver Sees Pickup Code

The receiver app should show the pickup code. For testing:
- Check the console log for the generated code
- Or query Firestore directly

#### Step 5: Donor Verifies Pickup Code

1. In Flutter app, click: **"Donor: Enter Pickup Code"**
2. Enter the 4-digit code from Step 3
3. Click **"VERIFY & COMPLETE"**

**Expected Result:**
- ✅ Pickup code validated
- ✅ Payment voided (₹50 refunded to receiver)
- ✅ Donation status changed to "completed"
- ✅ Both users receive karma points

**Verify in Razorpay Dashboard:**
- Payment status: **"Cancelled/Refunded"**
- No money deducted from receiver

### Flow 2: No-Show (Forfeiture)

#### Step 1-3: Same as Flow 1

Complete payment and simulate webhook.

#### Step 4: Wait for Expiry (or Simulate)

**Option A: Wait 24 hours** (not practical for testing)

**Option B: Manually expire the transaction**

1. Go to Firestore: http://localhost:4000/firestore
2. Find the transaction document
3. Change `pickup_code_expires` to a past timestamp
4. Or run the scheduled function manually:

```bash
# Trigger the scheduled function via emulator
curl -X POST http://localhost:5001/demo-project/asia-southeast1/checkExpiredAuthorizations
```

#### Step 5: Check Forfeiture

**Expected Result:**
- ✅ Payment captured (₹50 deducted from receiver)
- ✅ Transaction status: "captured"
- ✅ Donation status reset to "active"
- ✅ Receiver loses karma points

**Verify in Razorpay Dashboard:**
- Payment status: **"Captured"**
- ₹50 deducted from receiver's account

### Flow 3: Invalid Pickup Code

#### Step 1-3: Same as Flow 1

Complete payment and simulate webhook.

#### Step 4: Enter Wrong Code

1. Donor enters wrong code: `0000`
2. Click **"VERIFY & COMPLETE"**

**Expected Result:**
- ❌ Error: "Invalid pickup code"
- Donor can retry
- No payment changes

### Flow 4: UPI Payment

#### Step 1: Pay with UPI

1. Click **"PAY ₹50"**
2. Select **"UPI"** from payment options
3. Enter UPI ID: `test@upi`
4. Complete payment

**Note:** UPI in test mode may behave differently. Use card payment for consistent testing.

## Testing Checklist

### Backend Tests

- [ ] `createPaymentOrder` creates order with `payment_capture: 0`
- [ ] Webhook receives `payment.authorized` event
- [ ] Transaction record created with pickup code
- [ ] `verifyPickupCode` validates correct code
- [ ] `verifyPickupCode` rejects incorrect code
- [ ] `checkExpiredAuthorizations` captures expired payments
- [ ] Idempotency prevents duplicate orders

### Frontend Tests

- [ ] Razorpay checkout opens on web
- [ ] Razorpay checkout opens on mobile
- [ ] UPI option visible
- [ ] Card payment works
- [ ] Success callback received
- [ ] Error handling works
- [ ] Loading states shown

### Integration Tests

- [ ] End-to-end happy path works
- [ ] No-show forfeiture works
- [ ] Invalid code handling works
- [ ] Transaction history displays
- [ ] Pickup code expires after 24h

## Debugging Tips

### Check Browser Console

```javascript
// In Chrome DevTools Console
// Look for:
"Opening Razorpay Checkout..."
"Razorpay checkout opened successfully"
"Razorpay Web Success: pay_xxxxx"
```

### Check Firebase Emulator Logs

```bash
# View logs in real-time
tail -f emulator.log

# Or check the emulator UI
open http://localhost:4000/logs
```

### Check Firestore Data

```bash
# Open Firestore emulator UI
open http://localhost:4000/firestore

# Look for collections:
# - donations
# - transactions
# - idempotencyKeys
```

### Common Issues

**Issue:** Payment authorized but no transaction created

**Solution:**
1. Check webhook simulation ran successfully
2. Check Functions log for errors
3. Verify transaction document in Firestore

**Issue:** Pickup code not working

**Solution:**
1. Check transaction exists in Firestore
2. Verify `pickup_code_expires` is in the future
3. Check `payment_status` is "authorized"

**Issue:** Razorpay checkout not opening

**Solution:**
1. Check `.env` file has correct `RAZORPAY_KEY_ID`
2. Verify `web/index.html` has Razorpay script
3. Check browser console for JS errors
4. Hot restart Flutter app

## Load Testing (Optional)

Test multiple concurrent payments:

```bash
# Run multiple webhook simulations
cd functions/scripts
for i in {1..5}; do
  npx ts-node simulate_webhook.ts &
done
wait
```

## Production Testing

Before going live:

1. Switch to Razorpay **Live Mode**
2. Update `.env` with live keys
3. Deploy functions: `firebase deploy --only functions`
4. Use real payment methods (small amounts)
5. Test actual refund timeline (5-7 days)

## Test Data Cleanup

After testing, clean up Firestore:

```bash
# Delete test data (run in Firestore emulator)
firebase firestore:delete --recursive /donations/test_donation_123
firebase firestore:delete --recursive /transactions
```

## Support

If you encounter issues:

1. Check this guide's troubleshooting section
2. Review README.md
3. Check Firebase emulator logs
4. Check Razorpay dashboard for payment status
