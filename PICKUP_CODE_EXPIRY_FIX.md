# Pickup Code Expiry Fix - Complete Solution

## Problem Identified
The pickup code screen shows **717 hours (30 days)** instead of **24 hours** because:
1. Transaction documents exist but use wrong expiry field
2. Missing `pickup_code_expires` field in transactions
3. Fallback to donation's `expires_at` (30 days) instead of 24-hour pickup window

## Root Cause
- Transactions ARE being created (we see pickup codes working)
- But `pickup_code_expires` field is missing or incorrect
- Code falls back to `expires_at` which is 30 days from donation creation

## Solution Implemented

### 1. Created Missing Cloud Functions

#### a. `getTransaction` - Fetch transaction data
```typescript
// File: functions/src/getTransaction.ts
// Purpose: Retrieve transaction with correct pickup_code_expires
// Usage: Called by lib/screens/profile/pickup_code_screen.dart
```

#### b. `createTransactionOnPayment` - Create transaction with 24h expiry  
```typescript
// File: functions/src/createTransactionOnPayment.ts
// Purpose: Create transaction document with correct pickup_code_expires (24h from payment)
// Usage: Call after successful Razorpay payment
```

#### c. `fixTransactionExpiry` - Fix existing transactions
```typescript
// File: functions/src/fixTransactionExpiry.ts  
// Purpose: One-time fix to add pickup_code_expires to existing transactions
// Usage: Call once to fix all existing transactions
```

### 2. Updated Pickup Code Screen
```dart
// File: packages/razorpay_plugin/lib/screens/pickup_code_screen.dart
// Added: _fetchTransactionFromFirestore() to get fresh data
// Added: Debug logging to verify correct field is read
```

## Deployment Steps

### Step 1: Deploy Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions:getTransaction
firebase deploy --only functions:createTransactionOnPayment  
firebase deploy --only functions:fixTransactionExpiry
```

### Step 2: Fix Existing Transactions
Call the fix function once:
```dart
// In Flutter app (debug mode)
final result = await FirebaseFunctions.instance
  .httpsCallable('fixTransactionExpiry')
  .call();
print('Fixed ${result.data['fixedCount']} transactions');
```

### Step 3: Verify Fix
1. Open app and reserve an item
2. Complete payment
3. Check pickup code screen
4. Timer should show ~24h (not 717h)

## Debug Logging

The code now includes extensive logging:
```
[PickupCodeScreen] Reading expiry fields:
  - pickup_code_expires: Timestamp(2026-03-13 10:00:00)
  - expires_at: Timestamp(2026-04-12 10:00:00)  // 30 days later!
[PickupCodeScreen] Expiry calculated:
  - Expiry date: 2026-03-13 10:00:00.000
  - Time remaining: 23:59:59.123456
[PickupCodeScreen] Code valid, hours: 23
```

## Field Priority

The code now correctly prioritizes:
1. `pickup_code_expires` ← **Correct (24h)**
2. `expires_at` ← Only if pickup_code_expires missing
3. Default to 23h 59m

## Expected Behavior

| Time | Display | Color |
|------|---------|-------|
| 24h 0m 0s | "24h 0m 0s" | 🟢 Green |
| 6h 30m 15s | "6h 30m 15s" | 🟢 Green |
| 5h 45m 30s | "5h 45m 30s" | 🟠 Orange |
| 0h 45m 30s | "45m 30s" | 🔴 Red |
| 0h 0m 30s | "30s" | 🔴 Red |
| Expired | "Expired" | 🔴 Red |

## Files Modified

| File | Purpose |
|------|---------|
| `functions/src/getTransaction.ts` | NEW - Fetch transaction |
| `functions/src/createTransactionOnPayment.ts` | NEW - Create transaction |
| `functions/src/fixTransactionExpiry.ts` | NEW - Fix existing |
| `functions/src/index.ts` | Export new functions |
| `packages/razorpay_plugin/lib/screens/pickup_code_screen.dart` | Enhanced logging & fetch |

## Testing Checklist

- [ ] Deploy all 3 new Cloud Functions
- [ ] Call `fixTransactionExpiry` once
- [ ] Reserve new item
- [ ] Verify timer shows ~24h
- [ ] Wait for timer to update (should countdown)
- [ ] Verify color changes (green → orange → red)

## Notes

- Transaction creation should happen AFTER payment success
- Use `createTransactionOnPayment` Cloud Function
- Pass: donationId, razorpayPaymentId, razorpayOrderId, promiseFee
- Returns: transactionId, pickupCode (4-digit)
