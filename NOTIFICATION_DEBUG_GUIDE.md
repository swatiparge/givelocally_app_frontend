# Notification System Debug Guide

## 🔍 Issue Identified

When a new donation is created, nearby users are NOT receiving notifications. The notification screen shows "No notifications yet".

## 🎯 Root Cause

The backend Cloud Function `createdonation` is **NOT** automatically sending FCM notifications to nearby users when a donation is created.

Looking at the deployed Cloud Functions:
- ✅ Frontend calls `https://createdonation-u6nq5a5ajq-as.a.run.app` (deployed externally)
- ✅ Frontend calls `https://getnotifications-u6nq5a5ajq-as.a.run.app` (deployed externally)
- ❌ Backend does NOT trigger notifications on donation creation

## 🔧 What Needs to Be Fixed (Backend)

### 1. Add Firestore Trigger for New Donations

Create a Cloud Function that triggers when a new document is added to `donations` collection:

```javascript
// functions/src/notifyNearbyUsers.ts
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

export const notifyNearbyUsers = functions.firestore
  .document("donations/{donationId}")
  .onCreate(async (snap, context) => {
    const donation = snap.data();
    const donationId = context.params.donationId;
    
    // Get donation location
    const lat = donation.location.latitude;
    const lng = donation.location.longitude;
    const donorId = donation.donorId;
    
    // Query users within ~5km radius
    // Note: You'll need geospatial indexing or bounding box query
    const usersSnapshot = await admin.firestore()
      .collection("users")
      .where("location", ">=", /* calculate bounding box */)
      .get();
    
    // Filter users by distance (Haversine formula)
    const nearbyUsers = usersSnapshot.docs.filter(doc => {
      const user = doc.data();
      const distance = calculateDistance(
        lat, lng, 
        user.location.latitude, 
        user.location.longitude
      );
      return distance <= 5 && doc.id !== donorId; // Within 5km, not the donor
    });
    
    // Send FCM notifications
    const promises = nearbyUsers.map(async userDoc => {
      const user = userDoc.data();
      const tokens = user.fcm_tokens || [];
      
      if (tokens.length === 0) return;
      
      const message = {
        notification: {
          title: "New Donation Nearby!",
          body: `${donation.title} - ${donation.distance?.toStringAsFixed(1) ?? '?'} km away`,
        },
        data: {
          type: "donation_listed",
          donationId: donationId,
          title: donation.title,
          category: donation.category,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        tokens: tokens,
      };
      
      try {
        const response = await admin.messaging().sendMulticast(message);
        console.log(`FCM sent to ${userDoc.id}: ${response.successCount}/${tokens.length} successful`);
        
        // Store notification in user's notifications collection
        await admin.firestore()
          .collection("users")
          .doc(userDoc.id)
          .collection("notifications")
          .add({
            type: "donation_listed",
            title: "New Donation Nearby",
            body: `${donation.title} was just listed`,
            donationId: donationId,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      } catch (error) {
        console.error(`Failed to send FCM to ${userDoc.id}:`, error);
      }
    });
    
    await Promise.all(promises);
  });

// Helper function to calculate distance
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}
```

### 2. Export the New Function

Update `functions/src/index.ts`:

```typescript
import * as functions from "firebase-functions";
import {verifyPickupCode} from "./verifyPickupCode";
import {notifyNearbyUsers} from "./notifyNearbyUsers";

// Export all Cloud Functions
export {verifyPickupCode, notifyNearbyUsers};

// Optional: Default export for testing
export default {
  verifyPickupCode,
  notifyNearbyUsers,
};
```

### 3. Deploy the Cloud Function

```bash
cd functions
npm run build
firebase deploy --only functions:notifyNearbyUsers
```

## 📱 Frontend Changes (Already Implemented)

### ✅ FCM Token Management
- Token is retrieved and stored in `users/{userId}/fcm_tokens` array
- Token refresh is handled automatically

### ✅ Foreground Notification Handling
- Snackbar shown when app is in foreground
- Notification added to local provider state
- Auto-refresh on app resume

### ✅ Notification Screen
- Pull-to-refresh support
- Manual refresh button in app bar
- Debug dialog with FCM status
- Better error logging

## 🧪 Testing Steps

### Step 1: Verify FCM Token Storage
1. Open app and login
2. Check Firebase Console → Firestore → users → {yourUserId}
3. Verify `fcm_tokens` array contains your device token
4. Also check `lastTokenUpdate` timestamp

### Step 2: Verify Backend Trigger
1. Open Firebase Console → Functions
2. Check if `notifyNearbyUsers` function exists
3. If not, deploy it (see above)

### Step 3: Test Notification Flow
1. Device A: Login and set location
2. Device B: Login and create a donation near Device A's location (within 5km)
3. Device A: Should receive:
   - System notification (if app in background)
   - Snackbar notification (if app in foreground)
   - Notification added to notification list
4. Device A: Open notification screen → should see the new notification

### Step 4: Debug with Logs

Check Firebase Console → Functions → Logs for:
```
FCM sent to {userId}: X/Y successful
```

## 🚨 Common Issues

### Issue 1: "No notifications yet" after creating donation
**Cause**: Backend Cloud Function not sending notifications
**Fix**: Deploy the `notifyNearbyUsers` Cloud Function (see above)

### Issue 2: FCM token not saved
**Cause**: Permission denied or initialization error
**Fix**: 
- Check Firestore rules allow writing to `users/{userId}/fcm_tokens`
- Check FCM initialization in app logs
- Verify `requestPermission()` was called and user granted permission

### Issue 3: Notifications not showing in foreground
**Cause**: App not listening to FCM foreground messages
**Fix**: 
- Verify `NotificationListenerWidget` is wrapped around app
- Check `FcmService.initialize()` is called in main.dart

### Issue 4: Distance calculation wrong
**Cause**: Haversine formula or coordinate conversion issue
**Fix**:
- Verify `location` field is GeoPoint type in Firestore
- Check coordinate system (lat/lng order)
- Use proper bounding box query for Firestore

## 📊 Expected Flow

```
Device B Creates Donation
    ↓
createdonation Cloud Function (stores in Firestore)
    ↓
notifyNearbyUsers Firestore Trigger (NEW - needs to be added)
    ↓
Query nearby users from Firestore
    ↓
Send FCM to each user's fcm_tokens
    ↓
Device A Receives FCM
    ↓
If foreground: Show Snackbar + Add to list
If background: Show system notification
    ↓
getNotifications API returns notification
    ↓
Notification Screen displays it
```

## 🔗 Key Files

- Frontend FCM Service: `lib/services/fcm_service.dart`
- Frontend Notification Provider: `lib/providers/notification_provider.dart`
- Frontend Notification Screen: `lib/screens/notifications/notifications_screen.dart`
- Backend Functions: `functions/src/index.ts` (NEEDS notifyNearbyUsers)
- Backend Firebase Config: `functions/src/config/firebase.ts`

## 💡 Next Steps

1. **Deploy the backend fix** (highest priority)
2. Test with two devices
3. Monitor Firebase Functions logs
4. Adjust distance threshold if needed (currently 5km)
5. Add rate limiting if needed (prevent spam notifications)

---

**Note**: The frontend notification system is fully implemented and working. The issue is entirely on the backend side - the Cloud Function trigger needs to be deployed.
