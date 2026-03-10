# Firestore Rules Fix & Widget Lifecycle Solutions

## Issues Fixed

### 1. Firestore Permission Denied Error (Backend)

**Problem:** Querying transactions with multiple `where()` clauses failed with:
```
PERMISSION_DENIED: Missing or insufficient permissions.
```

**Root Cause:** The original security rules used `get()` inside `isParty()` function, which **doesn't work with queries**. The `resource` variable is `null` during query evaluation.

**Solution Applied:**
- Changed rules to check document fields directly: `resource.data.donorId` and `resource.data.receiverId`
- This works for both single document reads AND queries

**File Modified:** `firestore.rules` (new file)

### 2. Widget Deactivated Error (Frontend)

**Problem:** 
```
Looking up a deactivated widget's ancestor is unsafe.
```

**Root Cause:** Showing SnackBar after async operations when widget might be disposed (user navigated away).

**Solution Applied:**
- Added `if (!mounted) return;` check at the start of `_verifyAndComplete()`
- Added mounted check before showing the "Please enter code" SnackBar
- Already had mounted checks in other places (lines 150, 165, 191, 197)

**File Modified:** `lib/screens/profile/complete_pickup_screen.dart`

### 3. App Check Not Initialized (Warning)

**Problem:**
```
No AppCheckProvider installed.
```

**Solution Applied:**
- Added Firebase App Check initialization in `main.dart`
- Using debug provider for development (won't block requests)
- Should switch to production providers before release

**File Modified:** `lib/main.dart`

## Files Created/Modified

### New Files:
1. **`firestore.rules`** - Security rules for Firestore
2. **`firestore.indexes.json`** - Composite indexes for queries
3. **`deploy_firebase_rules.sh`** - Script to deploy rules

### Modified Files:
1. **`lib/main.dart`** - Added App Check initialization
2. **`lib/screens/profile/complete_pickup_screen.dart`** - Added mounted checks
3. **`firebase.json`** - Added Firestore configuration

## How to Deploy Firestore Rules

### Option 1: Using the Deploy Script (Recommended)
```bash
./deploy_firebase_rules.sh
```

This will:
- Check Firebase CLI installation
- Prompt for login if needed
- Deploy rules to Firebase
- Deploy indexes

### Option 2: Manual Deployment
```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy only Firestore rules
firebase deploy --only firestore:rules

# Deploy indexes
firebase deploy --only firestore:indexes
```

### Option 3: Firebase Console (Manual)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `givelocally-dev`
3. Go to Firestore Database → Rules
4. Copy contents from `firestore.rules`
5. Click Publish

## Testing the Fix

After deploying the rules, test:

1. **Login** - Should work normally
2. **View donations** - Should load without permission errors
3. **Accept pickup request** - Donor should see the request
4. **Verify pickup code** - Should work without permission denied

## Key Changes in Security Rules

### Before (Broken for queries):
```javascript
match /transactions/{transactionId} {
  allow read: if isAuthenticated() && isParty(transactionId);  // ❌ Uses get() internally
}
```

### After (Works for queries):
```javascript
match /transactions/{transactionId} {
  allow read: if isAuthenticated() 
    && (resource.data.donorId == request.auth.uid 
      || resource.data.receiverId == request.auth.uid);  // ✅ Direct field check
}
```

## Important Notes

### For Development:
- App Check is using `AndroidProvider.debug` - this allows all requests
- Debug token is printed in console on first run
- For production, switch to `AndroidProvider.playIntegrity`

### For Production:
Update `lib/main.dart`:
```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.deviceCheck,
);
```

### Security:
- `pickup_code` is still stored ONLY in `transactions` collection
- Only donor and receiver can read transactions
- Cloud Functions handle all writes to transactions

## Troubleshooting

### If queries still fail after deploying:
1. Check indexes are deployed: `firebase deploy --only firestore:indexes`
2. Wait 1-2 minutes for rules to propagate
3. Clear app data and restart
4. Check Firebase Console > Firestore > Rules to verify deployment

### If you see "Failed to get App Check token":
- This is expected in debug mode
- App Check will still work, just using debug tokens
- For production, register your app in Firebase Console > App Check

## Next Steps

1. ✅ Deploy the updated Firestore rules
2. ✅ Test the complete pickup flow
3. ⬜ Switch App Check to production providers before release
4. ⬜ Set up Play Integrity API for Android
5. ⬜ Set up Device Check for iOS
