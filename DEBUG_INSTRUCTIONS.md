# Debug Instructions for Pickup Code Expiry

## Problem
Firebase shows correct expiry (24h), but app shows 717h (30 days)

## What I Added
Extended debug logging in `lib/screens/profile/pickup_code_screen.dart`

## How to Test

1. **Run the app in debug mode**
2. **Open any pickup code screen** (or your existing reservation)
3. **Check the debug console** for output like:

```
PICKUP_CODE _getTimeRemaining called
  - All keys: [list of all field names]
  - pickup_code_expires: Timestamp(...)
  - expires_at: Timestamp(...)
  - authorization_expires: Timestamp(...)
  - Expiry from Timestamp: 2026-03-12 23:56:39.000
  - Time difference: 23:59:58.123456
  - Hours: 23, Minutes: 59
  - Final result: 23h 59m
```

## What to Look For

### ✅ If Working Correctly:
- `pickup_code_expires` shows a Timestamp
- Expiry date is ~24 hours from now
- Final result shows "23h 59m" or similar

### ❌ If Still Showing 717h:
Check these in the debug output:

1. **Wrong field being read:**
   ```
   - pickup_code_expires: null  ← Should NOT be null!
   - expires_at: Timestamp(2026-04-12)  ← This is 30 days!
   ```

2. **Wrong document being read:**
   - Check if `donationId` matches the transaction
   - Verify you're looking at the right transaction

3. **Data type issue:**
   ```
   - Unknown expiry format: String  ← Should be Timestamp
   ```

## Next Steps

After running the app, share the debug output. It will tell us:
- Which field is being read
- What the actual value is
- Why it's calculating 717h instead of 24h

This will pinpoint exactly where the problem is!
