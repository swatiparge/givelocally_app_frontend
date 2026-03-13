# 🚀 QUICK START - Fix Android Notifications

## ⚡ 1-Minute Fix

```bash
# 1. Navigate to project
cd /Users/apple/Documents/Work/mobile_apps_frontend

# 2. Clean and rebuild
flutter clean && flutter pub get && flutter run

# 3. Check logs (in new terminal)
adb logcat | grep -i "fcm"
```

## ✅ Expected Output

```
FCM: Initializing...
FCM: Permission status: authorized
FCM: Token retrieved: eJz...
FCM: Token successfully pushed to Firestore
FCM: Initialization complete
```

## 🧪 Quick Test

1. **Open app** → Login
2. **Go to:** Profile → Notifications (bell icon)
3. **Tap:** "Debug FCM Status"
4. **Check:**
   - ✅ FCM Available: `true`
   - ✅ Token: `(30+ chars)`
   - ✅ User logged in: `(your UID)`
5. **Click:** "Add Test Notification"
6. **Should see:** Notification in list

## 🔍 If Not Working

### No token?
```bash
# Check google-services.json
cat android/app/google-services.json | grep "package_name"
# Should show: "com.givelocally.app"
```

### Token exists but no notifications?
1. Check Android permissions: **Settings → Apps → GiveLocally → Permissions → Notifications**
2. Check Firestore: **Firebase Console → Firestore → users/{uid} → fcm_tokens**
3. Check backend: **Firebase Console → Functions → Logs**

### Still stuck?
```bash
# Run full test script
./test_notifications.sh

# Or check detailed guide
cat NOTIFICATION_TESTING_ANDROID.md
```

## 📊 Success Checklist

- [ ] Token appears in debug screen
- [ ] Token saved to Firestore
- [ ] Notification permission granted
- [ ] Test notification appears
- [ ] Real notification appears (create donation from another account)

## 🎯 That's It!

If you see the token in debug screen and it's saved to Firestore, notifications should work.

**Full documentation:** See `NOTIFICATION_FIX_SUMMARY.md`

---
**Status:** ✅ Fixed | **Date:** 2026-03-12
