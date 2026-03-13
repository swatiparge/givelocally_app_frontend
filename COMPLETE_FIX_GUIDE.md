# Complete Fix Guide: Pickup Code Expiry

## Problem Summary
App shows 686h (28 days) instead of 24h because:
1. App reads donation document instead of transaction document
2. Donation has `expires_at` = 30 days from creation
3. Transaction has `pickup_code_expires` = 24 hours from payment ✅

## What's Been Fixed (Frontend)

### 1. Transaction Fetching
**File:** `lib/screens/profile/pickup_code_screen.dart`
- Now queries Firestore directly for transaction by `donationId`
- No longer relies on Cloud Functions
- Correctly prioritizes `pickup_code_expires` field

### 2. Data Flow Fix
**File:** `lib/screens/profile/received_items_screen.dart`
- Now passes `donationId` correctly to query transaction
- Removed confusion between transactionId and donationId

### 3. Debug Logging
Added extensive logging to trace the issue:
```
- pickup_code_expires: Timestamp(2026-03-12 23:56:39) ✅
- expires_at: Timestamp(2026-03-12 23:56:39) ✅
- Final result: 23h 59m ✅
```

## Backend Requirements (Firebase)

### What Already Exists ✅
From your Firebase screenshot, the transaction document has:
```
pickup_code_expires: March 12, 2026 at 11:56:39 PM (24h) ✅
expires_at: March 12, 2026 at 11:56:39 PM (24h) ✅
authorization_expires: March 12, 2026 at 11:56:39 PM (24h) ✅
pickup_code: "4793"
payment_status: "captured"
```

This is **CORRECT**! The backend is already creating transactions with 24h expiry.

### What Needs to Happen

The transaction document you showed in Firebase is ALREADY correct with 24h expiry. The problem was the frontend was reading the WRONG document (donation instead of transaction).

## Testing Steps

1. **Run the app**
2. **Open any pickup code screen** (from "Received Items" or "My Donations")
3. **Check debug console** for:
   ```
   Querying transaction for donationId: [your-donation-id]
   Found transaction: pickup_code_expires=Timestamp(2026-03-12 23:56:39)
   Found transaction: expires_at=Timestamp(2026-03-12 23:56:39)
   Final result: 23h 59m
   ```

4. **Verify on screen:**
   - Timer shows: "23h 59m" (or less, depending on when payment was made)
   - Color: Green (>6h), Orange (1-6h), Red (<1h)
   - Counts down in real-time

## If Still Showing Wrong Time

### Scenario A: Shows 686h or 717h
This means it's still reading donation data. Check:
```
PICKUP_CODE_SCREEN: Extracted donationId = [should be donation ID]
Querying transaction for donationId: [same ID]
```

If donationId is empty, the transaction query won't work.

### Scenario B: Shows "No transaction found"
This means:
1. Transaction doesn't exist in Firestore
2. Or Firestore security rules block the query

**Solution:** Check Firestore rules allow reading transactions:
```javascript
match /transactions/{transactionId} {
  allow read: if request.auth != null && 
    (resource.data.donorId == request.auth.uid || 
     resource.data.receiverId == request.auth.uid);
}
```

## Backend Checklist

- [x] Transaction document created with `pickup_code_expires` (24h)
- [x] Transaction document created with `expires_at` (24h)
- [x] Transaction has `pickup_code` (4 digits)
- [x] Transaction linked to `donationId`

All these exist in your Firebase! ✅

## Frontend Checklist

- [x] Query transaction by donationId
- [x] Read `pickup_code_expires` field
- [x] Display countdown timer
- [x] Update in real-time

All implemented! ✅

## Expected Result

Pickup code screen should now show:
- "Valid for: 23h 59m" (counting down)
- Green color (>6 hours)
- 4-digit pickup code
- Correct donor address

## No Backend Changes Needed!

Your Firebase backend is already creating transactions correctly with 24h expiry. The fix was entirely on the frontend to read the correct document.
