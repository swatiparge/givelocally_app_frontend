# 🔔 Notification Issues - Root Cause Analysis & Fixes

## ✅ Issues Fixed (2026-03-12)

### **Issue #1: Missing iOS Notification Permissions** ✅ FIXED
**Problem:** The `ios/Runner/Info.plist` was missing critical notification permissions.

**Solution:** Added to `Info.plist`:
```xml
<key>NSUserNotificationsUsageDescription</key>
<string>We send you notifications about new donations, messages, and pickup updates.</string>
<key>UIBackgroundModes</key>
<array>
<string>fetch</string>
<string>remote-notification</string>
</array>
```

### **Issue #2: iOS AppDelegate Not Configured for FCM** ✅ FIXED
**Problem:** The `AppDelegate.swift` wasn't setting up FCM notification delegates.

**Solution:** Updated `ios/Runner/AppDelegate.swift`:
```swift
import FirebaseMessaging

override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    FirebaseApp.configure()
    
    // CRITICAL: Enable FCM notifications
    if #available(iOS 10.0, *) {
        UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    application.registerForRemoteNotifications()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

### **Issue #3: FCM Token Sync Timing** ✅ FIXED
**Problem:** FCM token was being synced AFTER auth state changes, causing delays.

**Solution:** Reordered initialization in `lib/services/fcm_service.dart`:
```dart
Future<void> initialize() async {
    // 1. Setup background handler FIRST
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // 2. Setup listeners
    _messaging.onTokenRefresh.listen(_onTokenRefresh);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // 3. Request permissions EARLY
    await _requestPermissions();
    
    // 4. Get token IMMEDIATELY (CRITICAL FIX)
    await _syncTokenWithRetry();
    
    // 5. Then listen for auth changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) _syncToken();
    });
}
```

### **Issue #4: Token Not Saved to Firestore Properly** ✅ FIXED
**Problem:** Token sync wasn't including debug info and Cloud Function calls.

**Solution:** Enhanced `_sendTokenToServer()` in `lib/services/fcm_service.dart`:
```dart
await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
    'fcm_tokens': FieldValue.arrayUnion([token]),
    'lastTokenUpdate': FieldValue.serverTimestamp(),
    'fcmPlatform': Platform.operatingSystem,
    'fcm_token_debug': token, // For debugging
}, SetOptions(merge: true));

// Also call Cloud Function
try {
    final callable = _functions.httpsCallable('updateFcmToken');
    final result = await callable.call({
        'token': token,
        'platform': Platform.operatingSystem,
        'userId': user.uid,
    });
    debugPrint('✅ FCM: Cloud Function response: ${result.data}');
} catch (e) {
    debugPrint('⚠️ FCM: Cloud Function call failed: $e');
}
```

### **Issue #5: Notification Provider Reference Timing** ✅ IMPROVED
**Problem:** Global ref for notification provider might not be set when FCM messages arrive.

**Solution:** Improved timing in `lib/widgets/notification_listener_widget.dart`:
```dart
@override
void initState() {
    super.initState();
    
    // Set the global ref IMMEDIATELY in post frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
        FcmService.setGlobalRef(ref);
        debugPrint('NOTIFICATION_LISTENER: Global ref set');
    });
}
```

---

## 🧪 Testing Instructions

### **Step 1: Verify iOS Configuration**
```bash
cd ios
pod install
cd ..
```

### **Step 2: Run the App**
```bash
flutter run
```

### **Step 3: Check Debug Screen**
Navigate to: **Profile → Settings → Debug FCM Status**

You should see:
- ✅ FCM Available: true
- ✅ Token: (30+ characters)
- ✅ User logged in

### **Step 4: Test Notifications**
1. Login with your account
2. Go to another device/emulator
3. Create a donation as a different user
4. Check if the first device receives the notification

### **Step 5: Check Logs**
```bash
# Android
adb logcat | grep -i "fcm\|notification"

# iOS
flutter logs | grep -i "fcm\|notification"
```

Look for:
```
✅ FCM: Token retrieved: eyQ...
✅ FCM: Token successfully pushed to Firestore
📩 FCM: Foreground message received
```

---

## 🔍 Common Issues & Solutions

### **Issue: No Token**
**Symptoms:** FCM debug screen shows "No token"

**Solutions:**
1. **Android:** Check `google-services.json` exists in `android/app/`
2. **iOS:** Check `GoogleService-Info.plist` exists in `ios/Runner/`
3. **Both:** Rebuild the app after adding Firebase config files
4. **Emulator:** Make sure Google Play Services is installed

### **Issue: Token Exists But No Notifications**
**Symptoms:** Debug screen shows token, but no notifications appear

**Solutions:**
1. **Check Firestore:** Go to `users/{userId}` and verify `fcm_tokens` array has your token
2. **Check Backend:** Verify Cloud Functions are deployed and calling `admin.messaging().send()`
3. **Check Permissions:** On Android 13+, ensure notification permission is granted
4. **Check App Check:** In debug mode, ensure App Check debug token is registered

### **Issue: Notifications Work on One Device Only**
**Symptoms:** Only one device receives notifications

**Solutions:**
1. Each device gets a unique FCM token
2. Backend should save ALL tokens to `fcm_tokens` array
3. Backend should send to ALL tokens in the array

---

## 📋 Backend Checklist (Deploy Separately)

Make sure these Cloud Functions are deployed:

```javascript
// 1. On user creation - save FCM token
exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
    await admin.firestore().collection('users').doc(user.uid).set({
        fcm_tokens: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
});

// 2. Update FCM token (called from app)
exports.updateFcmToken = functions.https.onCall(async (data, context) => {
    const { token, userId } = data;
    await admin.firestore().collection('users').doc(userId).update({
        fcm_tokens: admin.firestore.FieldValue.arrayUnion([token])
    });
});

// 3. Send notification on donation
exports.onDonationCreated = functions.firestore
    .document('donations/{donationId}')
    .onCreate(async (snap, context) => {
        const donation = snap.data();
        const users = await getNearbyUsers(donation.location); // 5km radius
        
        for (const user of users) {
            const tokens = user.fcm_tokens || [];
            for (const token of tokens) {
                await admin.messaging().send({
                    token: token,
                    notification: {
                        title: 'New Donation Nearby!',
                        body: donation.title
                    },
                    data: {
                        type: 'nearby_donation',
                        donationId: context.params.donationId
                    }
                });
            }
        }
    });
```

---

## 🎯 Success Criteria

✅ **Android:**
- [ ] Token appears in debug screen
- [ ] Token saved to Firestore (`users/{userId}.fcm_tokens`)
- [ ] Notification permission granted (Android 13+)
- [ ] Foreground notifications appear
- [ ] Background notifications appear
- [ ] Tapping notification opens app

✅ **iOS:**
- [ ] `NSUserNotificationsUsageDescription` in Info.plist
- [ ] `UIBackgroundModes` includes `remote-notification`
- [ ] AppDelegate configures UNUserNotificationCenter
- [ ] Token appears in debug screen
- [ ] Foreground notifications appear
- [ ] Background notifications appear
- [ ] Tapping notification opens app

---

## 📞 Debug Commands

```bash
# Check FCM token
adb shell pm dump com.google.android.gms | grep -i fcm

# Clear app data (Android)
adb shell pm clear com.givelocally.app

# Check Firebase logs
firebase functions:log --only onDonationCreated

# Check Firestore
firebase firestore:delete --all-locations --recursive users/USER_ID

# Reinstall app
flutter clean
flutter pub get
flutter run
```

---

## 🚀 Next Steps

1. **Deploy backend Cloud Functions** (if not already done)
2. **Test on real devices** (not just emulators)
3. **Monitor Firebase Console > Functions logs**
4. **Check Firestore > users > fcm_tokens field**
5. **Test on both Android and iOS**

---

**Status:** ✅ All Flutter-side fixes applied
**Next:** Deploy backend functions and test end-to-end
