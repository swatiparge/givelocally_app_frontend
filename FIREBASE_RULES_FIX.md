# Firestore Rules Fix Required

## Problem Identified ✅
From debug output:
```
PERMISSION_DENIED: Missing or insufficient permissions.
```

The app CANNOT read the `transactions` collection due to Firestore security rules, even though:
- ✅ Transaction exists in Firebase
- ✅ Has correct `pickup_code_expires` (24h)
- ✅ Has correct `pickup_code` (4 digits)

## Solution: Update Firestore Security Rules

### Option 1: Update Rules (RECOMMENDED)

Go to **Firebase Console** → **Firestore** → **Rules** and update:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Allow users to read transactions they're involved in
    match /transactions/{transactionId} {
      allow read: if request.auth != null && 
        (request.auth.uid == resource.data.receiverId || 
         request.auth.uid == resource.data.donorId);
      
      // Only allow writes from backend (Cloud Functions)
      allow write: if false;
    }
    
    // Your existing rules for other collections
    match /donations/{donationId} {
      allow read: if request.auth != null;
      // ... your existing rules
    }
    
    match /users/{userId} {
      allow read: if request.auth != null;
      // ... your existing rules
    }
  }
}
```

### Steps to Update:
1. Go to https://console.firebase.google.com/
2. Select your project
3. Click "Firestore Database" in left menu
4. Click "Rules" tab
5. Update the rules as above
6. Click "Publish"
7. Test the app again

### Option 2: Backend Creates Transaction with Expiry Fields

If you CANNOT update rules, the backend that creates transactions must ensure:
- ✅ `pickup_code_expires` field is set (24h from creation)
- ✅ `expires_at` field is set (24h from creation)
- ✅ Transaction is linked to `donationId`

From your Firebase screenshot, this already exists! The issue is just the app can't READ it.

## Current Status

| Component | Status |
|-----------|--------|
| Transaction exists in Firebase | ✅ YES |
| Has `pickup_code_expires` (24h) | ✅ YES |
| Has `pickup_code` | ✅ YES |
| App can query transactions | ❌ NO (permission denied) |
| App shows correct expiry | ❌ NO (reading donation instead) |

## After Rules Update

Once you update the Firestore rules, the app will:
1. Query transaction by `donationId`
2. Get `pickup_code_expires` = 24h from payment
3. Show "23h 59m" timer (not 494h)
4. Countdown in real-time

## Test After Rules Update

1. Update Firestore rules
2. Run the app
3. Open pickup code screen
4. Debug should show:
   ```
   Query returned 1 docs
   Found transaction:
     - pickup_code_expires: Timestamp(2026-03-12 23:56:39)
     - Final result: 23h 59m
   ```

## No Backend Code Changes Needed

Your backend is already creating transactions correctly! Just needs rules update so app can READ them.
