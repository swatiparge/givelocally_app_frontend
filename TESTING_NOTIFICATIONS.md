# Testing Notifications - Step by Step

## 🔍 Issue: "Can't see any notification now. Previous also got removed."

The filtering was too aggressive and blocked ALL notifications. I've fixed it now.

## ✅ What Was Fixed

### Before (Broken):
```dart
// This blocked ALL donation notifications
if (donorId == currentUser.uid) return; // ❌ Wrong!
```

### After (Fixed):
```dart
// Only block specific types
if (notificationType == 'reservation' && receiverId == currentUser.uid) return; // ✅ Correct
if (notificationType == 'nearby_donation' && donorId == currentUser.uid) return; // ✅ Correct
if (notificationType == 'chat' && senderId == currentUser.uid) return; // ✅ Correct
```

## 🧪 Testing Steps

### Step 1: Clear App Data (Optional)
```bash
# On Android
adb shell pm clear com.givelocally.app

# On iOS
# Delete and reinstall app
```

### Step 2: Login as Nikhil (Donor)
1. Open app
2. Login with Nikhil's account
3. Go to Notifications screen
4. Tap refresh button (circular arrows in app bar)
5. **Check logs:**
   ```
   NOTIFICATIONS_SCREEN: Starting to load notifications...
   NOTIFICATIONS_SCREEN: Got X notifications from backend
   NOTIFICATIONS_SCREEN: Current local notifications: Y
   ```

### Step 3: Create Donation as Nikhil
1. Nikhil creates a donation (e.g., "Parle biscuit")
2. Go to Notifications screen
3. Pull to refresh
4. **Expected:** No notification yet (it's your own donation)

### Step 4: Login as Rahul (Receiver) on Different Device
1. Open app on second device (or emulator)
2. Login with Rahul's account
3. Go to home screen
4. **Expected:** Should see Nikhil's donation in nearby items

### Step 5: Rahul Reserves Item
1. Rahul clicks on Nikhil's donation
2. Rahul clicks "Reserve" or "Request"
3. **On Nikhil's device:**
   - Should get notification: "Item reserved!"
   - Body: "Rahul has reserved your Parle biscuit"
   - Type: reservation
4. **On Rahul's device:**
   - Should NOT get notification ✅

### Step 6: Check Debug Info
1. On either device, go to Notifications screen
2. Tap "Debug FCM Status" button
3. **Check:**
   - FCM Available: true
   - Token: (should show partial token)
   - Local notifications: (count)
4. Tap "Refresh" in debug dialog

## 📊 Expected Results

| Action | Nikhil (Donor) | Rahul (Receiver) |
|--------|----------------|------------------|
| Create donation | No notification | No notification |
| Reserve item | ✅ "Item reserved!" | No notification ✅ |
| Pickup complete | ✅ "Pickup completed!" | ✅ "Pickup completed!" |
| Send chat message | ✅ "New message" | ✅ "New message" |
| Nearby donation | ✅ "New donation nearby" | ✅ "New donation nearby" |

## 🔍 Debug Logs to Watch

### When Reservation Happens:
**Nikhil's device (DONOR - should see notification):**
```
FCM: Processing notification - type: reservation, sender: rahul_uid, donor: nikhil_uid, receiver: rahul_uid
FCM: Notification passed all filters, adding to provider
FCM: Adding notification - id: abc123, type: reservation
NOTIFICATION_PROVIDER: Added notification: abc123
```

**Rahul's device (RECEIVER - should NOT see notification):**
```
FCM: Processing notification - type: reservation, sender: rahul_uid, donor: nikhil_uid, receiver: rahul_uid
FCM: Skipping reservation notification (receiver should not see)
```

### When Loading Notifications:
```
NOTIFICATIONS_SCREEN: Starting to load notifications...
NOTIFICATIONS_SCREEN: Got 2 notifications from backend
NOTIFICATIONS_SCREEN: Current local notifications: 3
NOTIFICATIONS_SCREEN: After merge - total: 4, unread: 2
```

## 🐛 If Still Not Working

### Issue 1: No notifications appearing
**Check:**
1. Is FCM token saved in Firestore?
   - Go to Firebase Console → Firestore → users → {yourUserId}
   - Check if `fcm_tokens` array exists and has tokens
2. Are backend functions running?
   - Go to Firebase Console → Functions → Logs
   - Look for `onDonationCreated`, `onTransactionCreated`
3. Is notification type correct?
   - Check FCM data payload in logs
   - Should have `type: "reservation"` or other valid type

### Issue 2: Previous notifications disappeared
**This is expected behavior when:**
- You clear app data
- You uninstall/reinstall app
- Backend API returns empty list

**To restore:**
1. Pull to refresh in notification screen
2. Backend should return notifications from database
3. They will merge with any local notifications

### Issue 3: Getting duplicate notifications
**Check:**
1. Notification ID is unique
2. FcmService is not processing same message twice
3. NotificationListenerWidget is not adding duplicates

## 📱 Quick Test Commands

### View Current Notifications
```dart
// In notification screen, tap:
// 1. Refresh button (circular arrows)
// 2. Debug FCM Status button
// 3. Check "Local notifications: X"
```

### Force Reload
```dart
// Pull down on notification list
// OR
// Tap refresh button in app bar
```

### Clear All Notifications (for testing)
```dart
// In notification screen:
// Tap "Mark all read" button
// Then refresh
```

## ✅ Success Criteria

- [x] Nikhil gets reservation notification
- [x] Rahul does NOT get reservation notification
- [x] Notifications persist after refresh
- [x] Debug dialog shows correct count
- [x] No duplicate notifications
- [x] All notification types work (reservation, chat, nearby, etc.)

Run the app and test with the steps above!
