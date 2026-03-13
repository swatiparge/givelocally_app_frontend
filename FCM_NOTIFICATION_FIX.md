# FCM Notification Fix Summary

## 🔧 Problem Fixed
**FCM messages were showing in Snackbar but NOT persisting in notification screen**

When a chat/message notification arrived via FCM:
- ✅ Snackbar appeared (foreground notification)
- ❌ Notification was NOT added to notification screen
- ❌ Notification list remained empty

## ✅ Root Cause
The `setNotifications()` method in notification provider **REPLACED** all notifications when fetching from backend API, wiping out any locally-added FCM messages.

## ✅ Changes Made

### 1. **Notification Provider** (`lib/providers/notification_provider.dart`)
- Changed `setNotifications()` to **MERGE** backend notifications with existing local FCM notifications
- Added duplicate detection by notification ID
- Added timestamp sorting (newest first)
- Added timestamp parsing helper

### 2. **Notification Screen** (`lib/screens/notifications/notifications_screen.dart`)
- Fixed navigation to use GoRouter instead of Navigator.push
- Added chat navigation support with proper parameters
- Added debug refresh button in app bar
- Added debug dialog for FCM status
- Added auto-refresh when app resumes
- Added informative message about local FCM capture

### 3. **FCM Service** (`lib/services/fcm_service.dart`)
- Already converting FCM messages to notification format
- Already adding to notification provider queue
- Navigation handling for notification taps

### 4. **Notification Listener Widget** (`lib/widgets/notification_listener_widget.dart`)
- Already listening to foreground messages
- Already adding to notification provider
- Wrapped around app in main.dart

## 🔄 How It Works Now

### When FCM Message Arrives:
1. **FCM Service** receives message
2. **NotificationListenerWidget** converts to notification format
3. **NotificationProvider** adds to local list via `addNotification()`
4. **NotificationScreen** displays it immediately
5. Snackbar appears (user sees alert)

### When Notification Screen Loads:
1. Calls API to fetch notifications from backend
2. **MERGES** backend notifications with local FCM notifications
3. **REMOVES** duplicates (same ID)
4. **SORTS** by timestamp (newest first)
5. Displays combined list

## 🧪 Testing Steps

### Test 1: Receive Message Notification
1. Open app on Device A
2. Open Notifications screen
3. From Device B, send a message to Device A
4. **Expected**: 
   - Snackbar appears on Device A
   - Notification appears in list
   - Badge count increases

### Test 2: Refresh Keeps Local Notifications
1. Receive a message notification (appears in list)
2. Pull to refresh or tap refresh button
3. **Expected**: 
   - Message notification STAYS in list
   - Not wiped out by backend fetch

### Test 3: Navigate to Chat from Notification
1. Tap a message notification
2. **Expected**: Opens ChatScreen with correct donation

## 📱 Navigation

### From Notification Screen:
- **Message notifications** → ChatScreen (via GoRouter)
- **Donation notifications** → DonationDetailScreen (via GoRouter)

### Routes Added:
- `/chat/:donationId` - Chat route

## 🐛 Debug Features

### Manual Refresh Button
- Located in app bar (circular arrows icon)
- Forces fetch from backend
- Merges with local notifications

### Debug FCM Status Button
- Located in empty state
- Shows:
  - FCM availability
  - Token status
  - Troubleshooting tips

### Auto-Refresh
- Refreshes when app resumes from background
- Logs: "App resumed, refreshing..."

## 📁 Files Modified

1. `lib/providers/notification_provider.dart`
   - Modified `setNotifications()` to merge instead of replace

2. `lib/screens/notifications/notifications_screen.dart`
   - Fixed navigation
   - Added refresh button
   - Added debug dialog
   - Added auto-refresh
   - Added informative messages

## 🎯 Expected Behavior

### Scenario: User receives message
**Before Fix:**
- Snackbar shows ✅
- Notification list empty ❌

**After Fix:**
- Snackbar shows ✅
- Notification appears in list ✅
- Badge count updates ✅
- Persists after refresh ✅
- Tap opens chat ✅

## 🔍 Logs to Watch

```
FCM: Foreground message received: {...}
FCM: Data: {type: chat, donationId: ..., ...}
NotificationListener: Processing foreground message
NOTIFICATIONS_SCREEN: Starting to load notifications...
NOTIFICATIONS_SCREEN: Got X notifications
```

## 🚨 Common Issues

### Issue: Still not seeing FCM messages in list
**Check:**
1. Is `NotificationListenerWidget` wrapping the app in main.dart?
2. Is FCM token saved in Firestore (`users/{uid}/fcm_tokens`)?
3. Is the message type "chat" or "message" in FCM data?
4. Check logs for "Processing foreground message"

### Issue: Duplicate notifications
**Solution:** Already handled - merged by ID, duplicates removed

### Issue: Notifications disappear after refresh
**Solution:** Already fixed - now merges instead of replaces

## ✅ Verification Checklist

- [ ] Receive FCM message → Shows in Snackbar
- [ ] Receive FCM message → Appears in notification list
- [ ] Pull to refresh → Notifications persist
- [ ] Tap message notification → Opens chat
- [ ] Badge count updates correctly
- [ ] Mark as read works
- [ ] Mark all as read works

## 📝 Notes

- **Backend notifications** (donation_listed, etc.) still need backend Cloud Function fix
- **Message notifications** now work entirely via FCM and persist locally
- The fix ensures FCM messages survive backend API refresh

## 🔗 Related Files

- `lib/services/fcm_service.dart` - FCM handling
- `lib/widgets/notification_listener_widget.dart` - Foreground listener
- `lib/providers/notification_provider.dart` - State management
- `lib/routes/app_router.dart` - Navigation routes
- `lib/main.dart` - App initialization

---

**Status:** ✅ Fixed and ready for testing
