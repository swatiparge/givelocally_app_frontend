# Quick Test - Are Notifications Working?

## Step 1: Add This Temporary Button

In your notifications screen, add this test button temporarily:

```dart
// Add to notifications_screen.dart, in _buildEmptyState() or anywhere visible
ElevatedButton(
  onPressed: () {
    ref.read(notificationNotifierProvider.notifier).addNotification({
      'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
      'title': '✅ TEST WORKS!',
      'body': 'If you see this, notifications are working!',
      'type': 'test',
      'donationId': 'test',
      'timestamp': DateTime.now().toIso8601String(),
      'isRead': false,
    });
    print('TEST: Added notification manually');
  },
  child: Text('🧪 TEST NOTIFICATIONS'),
),
```

## Step 2: Run the App and Click This Button

**If notification appears:** ✅ Provider works! Issue is FCM or Backend
**If notification doesn't appear:** ❌ Provider issue - check provider code

## Step 3: Check These Logs in Order

```
1. "FCM: Foreground message received" 
   → If missing: FCM not receiving from Firebase
   
2. "FCM: Processing notification - type: xxx"
   → If missing: FCM service not calling _addNotificationToProvider
   
3. "FCM: Notification passed all filters"
   → If missing: Notification being filtered out (check rules)
   
4. "FCM: Adding notification - id: xxx"
   → If missing: Something wrong before this line
   
5. "NOTIFICATIONS_SCREEN: Got X notifications"
   → Should show count from backend
   
6. "NOTIFICATIONS_SCREEN: After merge - total: Y"
   → Y should be > 0 if working
```

## Step 4: Test Real Scenario

1. Login as User A
2. Create donation
3. Login as User B (different account, same location)
4. User B should get `nearby_donation` notification

**Check User B's logs:**
- If you see "FCM: Processing notification" → Good
- If you see "FCM: Skipping" → Check why filtered
- If no logs at all → FCM not receiving

## Step 5: Firebase Console Checks

### Check 1: FCM Token
```
Firebase Console → Firestore → users → {yourUserId}
Should have: fcm_tokens: ["token123...", "token456..."]
```

### Check 2: Backend Functions
```
Firebase Console → Functions → Logs
Should see: onDonationCreated, onTransactionCreated, etc.
```

### Check 3: FCM Delivery
```
Firebase Console → Cloud Messaging → Reports
Should show message delivery stats
```

## Most Likely Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| No logs at all | FCM not initialized | Check `FcmService().initialize()` in main.dart |
| "No current user" | Not logged in | Login first |
| "Skipping self" | Testing with same user | Use different user accounts |
| "Skipping receiver" | Receiver testing reservation | This is correct! Only donor should see |
| Backend logs missing | Functions not deployed | Deploy backend functions |
| Token missing in Firestore | FCM registration failed | Wait 30s or restart app |

## Quick Command to See All Logs

```bash
flutter run | grep -i "fcm\|notification"
```

Run this in terminal while testing to see all notification logs in real-time.

## Expected Result

After clicking test button, you should see:
1. Notification appears in list immediately
2. Badge count increases
3. Log: "Added notification: test_xxx"

If this works → Provider is fine, issue is FCM/Backend
If this doesn't work → Provider issue

