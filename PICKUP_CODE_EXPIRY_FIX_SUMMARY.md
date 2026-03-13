# Pickup Code Expiry Fix - FINAL SOLUTION

## Problem
Pickup code screen shows **717 hours (30 days)** instead of **24 hours** because:
- Transaction documents were being created with wrong expiry field
- Missing `pickup_code_expires` field (should be 24h from payment)
- Code was falling back to donation's `expires_at` (30 days)

## Root Cause Found
The transaction creation was **completely missing** from the payment flow! 

When payment succeeds in `lib/services/razorpay_service.dart`, the code only showed a success message but **never created the transaction document** in Firestore.

## Solution Implemented

### 1. Added Transaction Creation in Payment Success Handler
**File:** `lib/services/razorpay_service.dart`

```dart
void _handlePaymentSuccess(PaymentSuccessResponse response) async {
  // Create transaction with correct 24h expiry
  final transactionRef = await FirebaseFirestore.instance
    .collection('transactions')
    .add({
      'razorpay_payment_id': response.paymentId,
      'razorpay_order_id': _lastOrderId,
      'payment_status': 'authorized',
      'promise_fee': 9,
      'pickup_code': _generatePickupCode(),
      'pickup_code_expires': Timestamp.fromDate(
        DateTime.now().add(Duration(hours: 24)), // ✅ 24h from now
      ),
      'authorization_expires': Timestamp.fromDate(
        DateTime.now().add(Duration(hours: 24)),
      ),
      'pickup_code_used': false,
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': Timestamp.fromDate(
        DateTime.now().add(Duration(hours: 24)), // ✅ Same as pickup_code_expires
      ),
      'donationId': _lastDonationId,
      'donorId': _lastDonorId,
      'receiverId': _currentUserId,
    });
}
```

### 2. Store Donation Data Before Payment
Updated `_openRazorpayCheckout()` to store donation data so it's available when payment succeeds:

```dart
void _openRazorpayCheckout({...}) {
  // Store for transaction creation
  _lastOrderId = orderId;
  _lastDonationId = donation['id'] ?? donation['donationId'];
  _lastDonorId = donation['donorId'] ?? donation['userId'];
  _currentUserId = user.uid;
  
  // Open Razorpay checkout
  _razorpay.open(options);
}
```

## How It Works Now

1. User clicks "Reserve" → `reserveItem()` called
2. Order created in backend → `_openRazorpayCheckout()` stores donation data
3. User completes payment → Razorpay calls `_handlePaymentSuccess()`
4. **NEW:** Transaction created with correct 24h expiry
5. Pickup code screen shows ~24h (not 717h)

## Testing

1. Reserve any item
2. Complete ₹9 payment
3. Check pickup code screen
4. Timer should show **23h 59m** (not 717h)
5. Timer should countdown in real-time

## Files Modified

| File | Change |
|------|--------|
| `lib/services/razorpay_service.dart` | Added transaction creation in `_handlePaymentSuccess()` |
| `lib/services/razorpay_service.dart` | Added donation data storage in `_openRazorpayCheckout()` |
| `lib/services/razorpay_service.dart` | Added `_generatePickupCode()` method |

## Expected Output

````
Debug Output:
"Payment Success: pay_abc123"
"Stored donation data for transaction:"
"  - donationId: donation123"
"  - donorId: user456"
"  - userId: user789"
"  - orderId: order_xyz"
"Transaction created: transaction789"
````

Pickup code screen:
- ✅ Shows: "Valid for: 23h 59m 58s" (counting down)
- ✅ Color: Green (>6h)
- ✅ Code: 4-digit (e.g., "4 0 3 4")

## Notes

- No backend changes needed
- No Firebase deployment needed
- Works with existing Firestore rules
- Transaction created client-side on payment success
- Expiry is exactly 24 hours from payment completion
