# 🔍 DEBUG: Rahul Donated → Nikhil Should Get Notification

## 📋 SCENARIO

```
Rahul (Donor) → Creates donation
       ↓
Backend Trigger (onDonationCreated)
       ↓
Find nearby users (within 50km)
       ↓
Nikhil (Receiver) → SHOULD get "nearby_donation" notification
```

---

## ✅ EXPECTED BEHAVIOR

### **Rahul (Donor):**
- ❌ Should NOT get "nearby_donation" notification (it's his own donation)
- ✅ SHOULD get notification when someone reserves his item
- ✅ SHOULD get notification when pickup is completed

### **Nikhil (Receiver, nearby):**
- ✅ SHOULD get "nearby_donation" notification
- ✅ Should see: "New donation nearby!" + "Rahul is giving away [item title]"

---

## 🧪 STEP-BY-STEP DEBUGGING

### Step 1: Check if Backend Triggered

**Firebase Console → Functions → Logs:**

Look for:
```
onDonationCreated: Processing...
Donation status: active, category: [category]
Geolocation bounding box: [lat, lng]
Found X potential users
Sending nearby donation notification to Y users
Successfully notified Z devices
```

**If you DON'T see this:**
- Backend function not deployed
- Function error (check logs for errors)
- Donation status not "active"

### Step 2: Check if Nikhil is in Range

**Backend calculates:**
```typescript
const minLat = loc.latitude - 0.5;  // ~50km
const maxLat = loc.latitude + 0.5;
const minLng = loc.longitude - 0.5;
const maxLng = loc.longitude + 0.5;
```

**Check:**
1. Rahul's donation location: `donations/{id}.location`
2. Nikhil's location: `users/{nikhil_uid}.location`
3. Calculate distance: Should be within ~50km

### Step 3: Check if Nikhil Has FCM Token

**Firebase Console → Firestore → `users/{nikhil_uid}`:**

Should have:
- ✅ `location`: GeoPoint (lat, lng)
- ✅ `fcm_tokens`: array with at least 1 token
- ✅ `is_banned`: false

**If missing:**
- Nikhil needs to login to app
- App should sync token automatically
- Check Nikhil's app logs for FCM initialization

### Step 4: Check Backend Filtering

**Backend filters users:**
```typescript
const recipientIds = potentialDocs
  .filter((doc) => {
    const uData = doc.data();
    const uLoc = uData.location as GeoPoint;
    const isDonor = doc.id === donation.donorId;  // Not the donor
    const hasTokens = uData.fcm_tokens?.length > 0;  // Has FCM token
    const inLngRange = uLoc && uLoc.longitude >= minLng && uLoc.longitude <= maxLng;
    return uLoc && inLngRange && !isDonor && hasTokens;
  })
  .map((doc) => doc.id)
  .slice(0, 50);
```

**Nikhil is excluded if:**
- ❌ He is the donor (Rahul)
- ❌ No FCM tokens saved
- ❌ Location not in range
- ❌ Location missing
- ❌ User is banned

### Step 5: Check Notification Sent to Nikhil

**In Nikhil's app logs:**
```bash
# On Nikhil's device
adb logcat | grep -i "fcm"
```

**Should see:**
```
📩 FCM: Foreground message received
📩 FCM: Type: nearby_donation
📩 FCM: Donor: [rahul_uid]
✅ FCM: Letting notification through
FCM: Adding notification to provider
FCM: ✅ Successfully added notification
```

**If Nikhil doesn't see this:**
- Notification not sent by backend
- Nikhil's token not in recipient list
- Backend filtered out Nikhil

---

## 🔍 COMMON ISSUES & SOLUTIONS

### Issue 1: Nikhil Not in Range

**Symptoms:** Backend logs show "No nearby users found"

**Solution:**
1. Check distance between Rahul and Nikhil
2. Backend uses 50km radius (0.5 degrees)
3. If Nikhil is farther, he won't get notification

**Test:**
```dart
// Calculate distance
import 'dart:math';

double calculateDistance(lat1, lon1, lat2, lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a = sin;
  var d = 2 * 6371 * asin(sqrt(
    a((lat2 - lat1) * p / 2) * a((lat2 - lat1) * p / 2) +
    c(lat1 * p) * c(lat2 * p) * c((lon2 - lon1) * p / 2) * c((lon2 - lon1) * p / 2)
  ));
  return d; // kilometers
}

// If distance > 50km, Nikhil won't get notification
```

### Issue 2: Nikhil Has No FCM Token

**Symptoms:** Backend logs show "0 users with valid tokens"

**Solution:**
1. Nikhil should open app and login
2. App should sync FCM token automatically
3. Check Firestore: `users/{nikhil_uid}.fcm_tokens` should have array
4. Check Nikhil's app logs for FCM initialization success

### Issue 3: Notification Sent But Not Received

**Symptoms:** Backend logs show "Successfully notified 1 devices" but Nikhil sees nothing

**Solution:**
1. Check Nikhil's Android permissions:
   - Settings → Apps → GiveLocally → Permissions → Notifications → ALLOWED
2. Check Nikhil's app is running (not force-closed)
3. Check Nikhil's notification settings in app
4. Try sending test notification from Firebase Console

### Issue 4: Rahul Gets Notification Instead of Nikhil

**Symptoms:** Wrong person gets notification

**Solution:**
This is a backend bug. The filter should exclude the donor:
```typescript
const isDonor = doc.id === donation.donorId;
// Should return true for Rahul, so he's excluded
```

---

## 🧪 TESTING WORKFLOW

### Setup:
1. **Device 1 (Rahul):** Login as Rahul
2. **Device 2 (Nikhil):** Login as Nikhil
3. Both devices should be within 50km

### Test:
1. **Device 1 (Rahul):** Create donation
2. **Device 2 (Nikhil):** Watch for notification

### Expected Results:

**Device 1 (Rahul - Donor):**
- ❌ No "nearby_donation" notification
- ✅ Donation appears in "My Donations"
- ✅ Status: "active"

**Device 2 (Nikhil - Receiver):**
- ✅ Receives "New donation nearby!" notification
- ✅ Can see donation in map/list view
- ✅ Can message Rahul

---

## 📊 BACKEND LOGS TO CHECK

### Firebase Console → Functions → Logs

**Look for:**
```
onDonationCreated triggered
Processing donation: [donation_id]
Donor: [rahul_uid]
Location: [lat, lng]
Found 10 potential users in bounding box
Filtered to 1 users with valid tokens
Sending notification to: [nikhil_uid]
Successfully sent to 1 devices
```

**If you see errors:**
```
Error: User not found
Error: No location data
Error: FCM token invalid
```

Fix the specific error shown.

---

## 🔧 QUICK FIXES

### Fix 1: Ensure Nikhil's Location is Saved

**On Nikhil's device:**
```dart
// Should be saved on login/profile setup
await FirebaseFirestore.instance.collection('users').doc(nikhilUid).set({
  'location': GeoPoint(latitude, longitude),
  'fcm_tokens': FieldValue.arrayUnion([token]),
}, SetOptions(merge: true));
```

### Fix 2: Manually Trigger Notification

**Firebase Console → Cloud Messaging:**
1. Click "New notification"
2. Enter title: "Test"
3. Enter body: "Test notification"
4. Select user: Nikhil's token
5. Send
6. Nikhil should receive it

If this works but backend doesn't send, issue is in backend logic.

### Fix 3: Check Backend Filtering

**In `notification.ts`:**
```typescript
// Make sure this filter is correct
const isDonor = doc.id === donation.donorId;
// Should exclude Rahul (donor)

const hasTokens = uData.fcm_tokens?.length > 0;
// Should include Nikhil if he has tokens

const inLngRange = uLoc && uLoc.longitude >= minLng && uLoc.longitude <= maxLng;
// Should include Nikhil if within range
```

---

## ✅ SUCCESS CHECKLIST

- [ ] Backend `onDonationCreated` triggered
- [ ] Donation location saved correctly
- [ ] Nikhil's location saved and within 50km
- [ ] Nikhil has FCM tokens in Firestore
- [ ] Backend finds Nikhil in bounding box
- [ ] Backend sends notification to Nikhil
- [ ] Nikhil's device receives notification
- [ ] Nikhil can see donation detail

---

## 📞 NEXT STEPS

1. **Check backend logs** in Firebase Console
2. **Verify locations** of both users
3. **Check Firestore** for FCM tokens
4. **Test on devices** with both accounts
5. **Share logs** if still not working

**Expected:** Nikhil gets notification within 5 seconds of Rahul creating donation  
**If not:** Check backend logs for exact error

---

**Last Updated:** 2026-03-12  
**Status:** Debugging in progress
