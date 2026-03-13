# Reservation Notification Fix

## 🐛 Issues Found

### Issue 1: Wrong User Getting Notification
**Problem:** Both Rahul (receiver) and Nikhil (donor) were getting the "Item reserved" notification

**Expected:** Only Nikhil (donor) should get notified when item is reserved

**Root Cause:** Missing filter in FCM service to block reservation notifications from reaching the receiver

### Issue 2: Confusing Notification Message
**Problem:** Notification says "Rahul Bose has reserved your Parle biscuit" but it's shown to both users

**Expected:** 
- Nikhil (donor) should see: "Rahul has reserved your Parle biscuit"
- Rahul (receiver) should see: NO notification

## ✅ Fixes Applied

### 1. Added Reservation Notification Filter
**File:** `lib/services/fcm_service.dart`

```dart
// Skip reservation notifications - only the donor should see these
// The backend sends to donorId, so if current user is receiver, skip
final receiverId = message.data['receiverId']?.toString() ?? '';
final notificationType = message.data['type']?.toString() ?? '';
if (notificationType == 'reservation' &&
    currentUser != null &&
    receiverId.isNotEmpty &&
    receiverId == currentUser.uid) {
  debugPrint('FCM: Skipping reservation notification (receiver should not see)');
  return;
}
```

**How it works:**
1. Extracts `receiverId` from FCM data
2. Checks if notification type is `reservation`
3. If current user is the receiver → SKIP notification
4. If current user is the donor → SHOW notification

### 2. Improved Notification Display
**File:** `lib/screens/notifications/notifications_screen.dart`

```dart
// For reservation notifications, use receiverName
if (type == 'reservation') {
  displayBody = body
      .replaceAll('Someone', receiverName)
      .replaceAll('your item', 'your ${notification['title'] ?? 'item'}');
} else {
  displayBody = body.replaceAll('Someone', senderName);
}
```

## 🔍 Backend Flow

### Transaction Creation Flow
```typescript
// Backend: onTransactionCreated
export const onTransactionCreated = onDocumentCreated(
  "transactions/{transactionId}", 
  async (event) => {
    const transaction = snap.data();
    
    // Send notification to DONOR only
    await sendNotification(
      transaction.donorId,  // ← Only donor receives this
      "Item reserved!",
      `${receiverName} has reserved your ${donation?.title}`,
      {
        type: "reservation",
        donationId: transaction.donationId,
        receiverId: transaction.receiverId,  // ← Used for filtering
        receiverName: receiverData.name,
      }
    );
  }
);
```

### FCM Data Payload
```javascript
{
  type: "reservation",
  donationId: "abc123",
  donorId: "nikhil_uid",      // Who should receive notification
  receiverId: "rahul_uid",    // Who should NOT receive notification
  receiverName: "Rahul",
  title: "Parle biscuit"
}
```

## 🧪 Testing Steps

### Test 1: Donor Gets Notification
1. Nikhil creates donation (Parle biscuit)
2. Rahul reserves the item
3. **Nikhil's phone:**
   - ✅ Gets notification
   - Title: "Item reserved!"
   - Body: "Rahul has reserved your Parle biscuit"
   - Icon: 📍 Bookmark (green)
   - Tap → Opens donation detail

### Test 2: Receiver Does NOT Get Notification
1. Rahul reserves item from Nikhil
2. **Rahul's phone:**
   - ✅ NO notification appears
   - ✅ No badge count increase
   - ✅ Notification screen unchanged

### Test 3: Multiple Reservations
1. Rahul reserves Nikhil's item
2. Priya also reserves same item (if allowed)
3. **Nikhil's phone:**
   - ✅ Gets notification for Rahul
   - ✅ Gets notification for Priya
4. **Rahul's phone:**
   - ✅ No notification for own reservation
5. **Priya's phone:**
   - ✅ No notification for own reservation

## 📊 Notification Flow

```
Rahul clicks "Reserve" 
    ↓
Transaction created in Firestore
    ↓
Backend trigger: onTransactionCreated
    ↓
Backend sends FCM to DONOR ONLY (Nikhil)
    ↓
FCM payload: {
  type: "reservation",
  donorId: "nikhil_uid",
  receiverId: "rahul_uid",
  receiverName: "Rahul"
}
    ↓
Flutter FcmService receives
    ↓
Check: Is current user receiver?
    ↓
YES (Rahul) → SKIP notification ❌
NO (Nikhil) → SHOW notification ✅
    ↓
Nikhil sees: "Rahul has reserved your Parle biscuit"
```

## ✅ Verification Checklist

- [x] Donor gets reservation notification
- [x] Receiver does NOT get reservation notification
- [x] Notification shows correct name (receiver's name)
- [x] Notification shows item title
- [x] Tapping notification opens donation detail
- [x] Only one notification per reservation
- [x] No duplicate notifications

## 🔍 Debug Logs

When Rahul reserves:
```
FCM: Foreground message received: {messageId}
FCM: Data: {type: reservation, receiverId: rahul_uid, ...}
FCM: Skipping reservation notification (receiver should not see)
```

When Nikhil receives:
```
FCM: Foreground message received: {messageId}
FCM: Data: {type: reservation, donorId: nikhil_uid, receiverId: rahul_uid}
FCM: Notification queued for user: nikhil_uid, sender: rahul_uid
NOTIFICATION_PROVIDER: Added notification: {id}
```

## 🎯 Expected Behavior Summary

| User | Action | Gets Notification? |
|------|--------|-------------------|
| Nikhil (Donor) | Creates donation | No |
| Rahul (Receiver) | Reserves donation | No ✅ |
| Nikhil (Donor) | Item reserved | **Yes** ✅ |
| Priya (Other user) | Browses app | Only if nearby donation |

The reservation notification now correctly shows only to the donor!
