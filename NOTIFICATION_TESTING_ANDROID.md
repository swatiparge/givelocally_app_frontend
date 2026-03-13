# 🔔 ANDROID NOTIFICATION TROUBLESHOOTING GUIDE

## ✅ Quick Checklist (Run These First)

### 1. Check Firebase Configuration
```bash
# Verify google-services.json exists
ls -la android/app/google-services.json

# Should exist and have correct package name
cat android/app/google-services.json | grep "package_name"
```

### 2. Check FCM Token in Firestore
1. Open Firebase Console → Firestore
2. Go to `users/{your_user_id}`
3. Check if `fcm_tokens` array exists and has your token
4. Token format: `eJz...` (long string, 150+ chars)

### 3. Check Android Permissions
On your Android device:
1. Settings → Apps → GiveLocally → Permissions
2. Ensure "Notifications" is ALLOWED (Android 13+)
3. For Android 13+, the app MUST request notification permission

### 4. Run Debug Commands
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check logs in real-time
adb logcat | grep -i "fcm\|notification\|firebase"
```

---

## 🧪 Step-by-Step Testing

### Test 1: FCM Initialization
Run the app and check logs for:
```
✅ FCM: Initializing...
✅ FCM: Permission status: authorized
✅ FCM: Token retrieved: eJz...
✅ FCM: Token successfully pushed to Firestore
✅ FCM: Cloud Function response: {...}
✅ FCM: Initialization complete
```

**If you don't see this:**
- Check `google-services.json` exists
- Check Firebase project is correct
- Rebuild the app

### Test 2: Token Saved to Firestore
1. Open Firebase Console → Firestore
2. Navigate to `users/{your_uid}`
3. Check field `fcm_tokens` (array)
4. Should contain your token

**If token not saved:**
- Check if user is logged in
- Check Firestore rules allow writes
- Check App Check isn't blocking

### Test 3: Send Test Notification
1. Login to app
2. Go to Profile → Settings → Debug FCM Status
3. Click "Add Test Notification"
4. Check if notification appears in list

**If test works but real notifications don't:**
- Backend issue (Cloud Functions not deployed)
- Check Firebase Console → Functions logs

### Test 4: Real Notification Flow
1. **Device A**: Login as User A (donor)
2. **Device B**: Login as User B (receiver, nearby location)
3. **Device A**: Create a donation
4. **Device B**: Should receive "New donation nearby!" notification

**Check logs on Device B:**
```
📩 FCM: Foreground message received
📩 FCM: Type: nearby_donation
✅ FCM: Letting notification through
FCM: Adding notification to provider
FCM: ✅ Successfully added notification
```

---

## 🚨 Common Issues & Solutions

### Issue 1: "No token" in debug screen
**Symptoms:** FCM debug shows "No token"

**Causes:**
- `google-services.json` missing or wrong
- Firebase project mismatch
- App Check blocking initialization

**Solutions:**
```bash
# 1. Verify google-services.json
cat android/app/google-services.json | grep "project_info"

# 2. Re-download from Firebase Console
# Firebase Console → Project Settings → Your apps → google-services.json

# 3. Rebuild
flutter clean
flutter pub get
flutter run
```

### Issue 2: Token exists but no notifications
**Symptoms:** Debug screen shows token, Firestore has token, but no notifications

**Causes:**
- Backend Cloud Functions not deployed
- Backend not sending to correct token
- Notification permission not granted (Android 13+)

**Solutions:**
1. **Check Firestore:**
   - Go to `users/{uid}/fcm_tokens`
   - Token should match what's in debug screen

2. **Check Backend:**
   - Firebase Console → Functions logs
   - Look for `onDonationCreated` trigger
   - Check if `sendNotificationToMultipleUsers` is called

3. **Check Android Permissions:**
   - Settings → Apps → GiveLocally → Permissions → Notifications
   - Must be ALLOWED

4. **Test manually:**
   - Firebase Console → Cloud Messaging
   - Send test message to token
   - Should appear on device

### Issue 3: Notifications appear but can't tap
**Symptoms:** Notification shows but tapping does nothing

**Causes:**
- Missing intent filter in AndroidManifest.xml
- Wrong notification click handler

**Solution:** Already fixed in AndroidManifest.xml:
```xml
<intent-filter>
  <action android:name="FLUTTER_NOTIFICATION_CLICK" />
  <category android:name="android.intent.category.DEFAULT" />
</intent-filter>
```

### Issue 4: Works on emulator but not device
**Symptoms:** Notifications work on emulator but not real device

**Causes:**
- Different Google Play Services version
- Device has battery optimization
- Device manufacturer restrictions (Xiaomi, Huawei, etc.)

**Solutions:**
1. **Disable battery optimization:**
   - Settings → Apps → GiveLocally → Battery → Unrestricted

2. **For Xiaomi/Huawei:**
   - Settings → Apps → GiveLocally → Autostart → ON
   - Settings → Apps → GiveLocally → Lock app in recent apps

3. **Check Play Services:**
   - Settings → Apps → Google Play Services
   - Should be updated

---

## 🔍 Debug Commands

### Check FCM Token
```bash
# Android logcat
adb logcat | grep -i "fcm.*token"

# Should show:
# FCM: Token retrieved: eJz...
# FCM: Token successfully pushed to Firestore
```

### Check Notification Permission
```bash
# Check if notification permission is granted
adb shell pm list permissions -g | grep notification
```

### Clear App Data
```bash
# Clear app data and rebuild
adb shell pm clear com.givelocally.app
flutter clean
flutter run
```

### Check Firebase Connection
```bash
# Run app and check Firebase initialization
flutter run --verbose 2>&1 | grep -i firebase
```

---

## 📊 Backend Verification

### 1. Check Cloud Functions are Deployed
Firebase Console → Functions → Should see:
- ✅ `onDonationCreated`
- ✅ `onMessageCreated`
- ✅ `onTransactionCreated`
- ✅ `onTransactionUpdated`
- ✅ `updateFcmToken`

### 2. Check Functions Logs
Firebase Console → Functions → Logs → Should see:
```
onDonationCreated: Processing...
Sending nearby donation notification to X users
Successfully notified Y devices
```

### 3. Verify Notification Payload
Backend should send:
```typescript
{
  type: "nearby_donation",
  donationId: "...",
  title: "Donation Title",
  donorName: "John",
  category: "appliances"
}
```

Flutter expects these exact field names!

---

## ✅ Success Criteria

### Android Notifications Working When:
- [ ] FCM token appears in debug screen
- [ ] Token saved to Firestore (`users/{uid}.fcm_tokens`)
- [ ] Notification permission granted (Android 13+)
- [ ] Foreground notification appears when app is open
- [ ] Background notification appears in notification tray
- [ ] Tapping notification opens app to correct screen
- [ ] Logs show: `📩 FCM: Foreground message received`

### Test All Notification Types:
1. **Nearby Donation** - User A creates donation, User B (nearby) gets notification
2. **Chat Message** - User A sends message, User B gets notification
3. **Reservation** - User B reserves item, User A (donor) gets notification
4. **Pickup Completed** - Pickup done, both users get notification

---

## 🆘 Emergency Commands

### Reset Everything
```bash
# 1. Uninstall app
adb uninstall com.givelocally.app

# 2. Clear Firebase data
# Firebase Console → Firestore → Delete user document

# 3. Reinstall
flutter clean
flutter pub get
flutter run
```

### Check App Check Status
```bash
# In debug logs, look for:
# ✅ App Check: Initialized successfully
# OR
# ⚠️ App Check: Initialization failed
```

### Force Token Refresh
```dart
// In Flutter app, go to debug screen
// Click "Reinitialize FCM"
// Check logs for new token
```

---

## 📞 Next Steps

1. **Run the app** with `flutter run`
2. **Check logs** with `adb logcat | grep -i fcm`
3. **Verify token** in Firestore Console
4. **Test notification** from Firebase Console → Cloud Messaging
5. **Create donation** and check if nearby device receives it

**If still not working:**
1. Share the output of `adb logcat | grep -i fcm`
2. Share screenshot of Firestore user document
3. Share screenshot of FCM debug screen

---

**Last Updated:** 2026-03-12  
**Status:** Flutter-side fixes applied ✅  
**Next:** Test on Android device
