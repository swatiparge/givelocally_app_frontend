# Notification Troubleshooting Guide

## 🚨 Issue: "Can't see any notification now. Previous also got removed."

## ✅ Quick Fixes Applied

### 1. Fixed Over-Filtering
**Problem:** All notifications were being blocked
**Fix:** Removed the line that blocked notifications if user wasn't the donor

### 2. Added Comprehensive Logging
Every step now logs what's happening - check these logs in order

## 🔍 Step-by-Step Diagnosis

### Step 1: Check if User is Logged In
```dart
// In FcmService._addNotificationToProvider
final currentUser = FirebaseAuth.instance.currentUser;
if (currentUser == null) {
  debugPrint('FCM: No current user, skipping notification');
  return; // ❌ This blocks everything
}
```
**✅ Action:** Make sure you're logged in before expecting notifications

### Step 2: Check FCM Token Status
```bash
# In Firebase Console:
# 1. Go to Firestore
# 2. Find your user: users/{yourUserId}
# 3. Check if fcm_tokens array exists and has values
```

**✅ Action:** If no token, the app isn't registering for FCM properly

### Step 3: Check if Backend is Sending
```bash
# In Firebase Console → Functions → Logs
# Look for:
# - onDonationCreated
# - onTransactionCreated  
# - onMessageCreated
```

**✅ Action:** If no logs, backend isn't triggering

### Step 4: Check Filtering Logic
The current filtering (CORRECT):
```dart
// Chat: Skip if you sent it yourself
if (type == 'chat' && senderId == currentUser.uid) return;

// Reservation: Skip if you're the receiver (not donor)
if (type == 'reservation' && receiverId == currentUser.uid) return;

// Nearby: Skip if it's your own donation
if (type == 'nearby_donation' && donorId == currentUser.uid) return;
```

## 🧪 Manual Test Procedure

### Test 1: Add Manual Test Notification
Create a file `lib/widgets/test_notification_button.dart`:
```dart
ElevatedButton(
  onPressed: () {
    ref.read(notificationNotifierProvider.notifier).addNotification({
      'id': 'test_123',
      'title': 'Test',
      'body': 'Test notification',
      'type': 'test',
      'timestamp': DateTime.now().toIso8601String(),
      'isRead': false,
    });
  },
  child: Text('Add Test'),
);
```

**Expected:** Notification appears in list immediately
**If not:** Provider issue

### Test 2: Check Notification Screen
1. Open Notifications screen
2. Pull to refresh
3. Check logs for:
   ```
   NOTIFICATIONS_SCREEN: Starting to load notifications...
   NOTIFICATIONS_SCREEN: Got X notifications from backend
   ```

**If X = 0:** Backend returned nothing
**If X > 0:** Notifications exist but might be filtered

### Test 3: Real FCM Test
1. Device A: Create donation
2. Device B (different user, nearby): Should get `nearby_donation`
3. Check Device B logs:
   ```
   FCM: Processing notification - type: nearby_donation
   FCM: Notification passed all filters
   FCM: Adding notification - id: xxx
   ```

## 📊 Decision Tree

```\
No notifications showing
│
├─ Is user logged in?
│  ├─ NO → Login first
│  └─ YES → Continue
│
├─ Is FCM token saved?
│  ├─ NO → Check Firebase Console → users/{uid}/fcm_tokens
│  └─ YES → Continue
│
├─ Is backend sending?
│  ├─ NO → Check Firebase Functions logs
│  └─ YES → Continue
│
├─ Is notification being filtered?
│  ├─ Chat message from self → ✅ Should filter
│  ├─ Reservation as receiver → ✅ Should filter
│  ├─ Own donation nearby → ✅ Should filter
│  └─ Other cases → Should NOT filter
│
└─ Is provider adding it?
   ├─ Check notificationNotifierProvider state
   └─ Should show count increasing
```

## 🔧 Common Issues & Fixes

### Issue 1: "No current user"
**Fix:** Login first, then wait for auth state

### Issue 2: "FCM token not saved"
**Fix:** 
1. Check Firestore rules allow writing
2. Wait for token refresh (can take 30s)

### Issue 3: "Backend not triggering"
**Fix:**
1. Check Firebase Functions are deployed
2. Check Functions logs for errors
3. Verify trigger paths match

### Issue 4: "Getting filtered"
**Check logs:**
```
FCM: Skipping reservation notification (receiver should not see)
```
**This is CORRECT behavior** - receiver shouldn't see reservation

### Issue 5: "Notifications disappear on refresh"
**Cause:** Backend returns empty list
**Fix:** Check backend API is returning notifications

## 📝 Debug Checklist

Run through this list:

- [ ] User is logged in
- [ ] FCM token exists in Firestore
- [ ] Backend function triggered (check logs)
- [ ] FCM message received (check logs: "FCM: Foreground message received")
- [ ] Passed filtering (check logs: "Notification passed all filters")
- [ ] Added to provider (check logs: "Added notification")
- [ ] Notification screen shows count
- [ ] Notification visible in list

## 🚀 Quick Test Command

Add this button to your notification screen temporarily:

```dart
ElevatedButton(
  onPressed: () {
    // Force add a notification
    ref.read(notificationNotifierProvider.notifier).addNotification({
      'id': 'debug_${DateTime.now().millisecondsSinceEpoch}',
      'title': 'Debug Test',
      'body': 'If you see this, notifications are working!',
      'type': 'debug',
      'timestamp': DateTime.now().toIso8601String(),
      'isRead': false,
    });
  },
  child: Text('Add Debug Notification'),
);
```

If this shows up → Provider works, issue is FCM or backend
If this doesn't show → Provider issue

## 📞 When All Else Fails

1. **Clear app data** and login fresh
2. **Check all debug logs** in order
3. **Test with debug button** first
4. **Verify backend** is actually sending

## ✅ Expected Flow (Working Example)

```
1. User logs in
   → FCM token saved to Firestore

2. Backend creates donation
   → onDonationCreated triggers
   → Queries nearby users
   → Sends FCM

3. FCM arrives at device
   → _handleForegroundMessage called
   → _addNotificationToProvider called
   → Passes all filters
   → Added to provider
   → State updates
   → UI rebuilds
   → Notification visible ✅
```

Follow this exact flow in your logs!
