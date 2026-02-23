# Razorpay Auth Capture Plugin

A pluggable Flutter plugin for Razorpay Authorization & Capture payment flow. This plugin can be integrated into any Flutter project to implement a "Promise Fee" pattern where money is held (not deducted) and released upon successful completion.

## Features

- ✅ **Authorization & Capture** - Hold money without deducting
- ✅ **Web & Mobile** - Works on all Flutter platforms
- ✅ **Firebase Backend** - Ready-to-use Cloud Functions
- ✅ **Pluggable** - Easy integration into existing projects
- ✅ **UPI, Cards, Netbanking** - Multiple payment methods
- ✅ **Pickup Code System** - Built-in verification flow
- ✅ **Transaction Management** - Track and query payments

## Architecture

```
┌─────────────────────────────────────────────┐
│         Your Flutter App                    │
│  ┌───────────────────────────────────────┐  │
│  │   razorpay_auth_capture plugin        │  │
│  │   • Payment UI Screens                │  │
│  │   • Payment Service                   │  │
│  │   • Transaction Management            │  │
│  └──────────────────┬────────────────────┘  │
└─────────────────────┼───────────────────────┘
                      │
┌─────────────────────┼───────────────────────┐
│         Firebase    │   Backend             │
│  ┌──────────────────┴────────────────────┐  │
│  │   Cloud Functions (Plugin)            │  │
│  │   • createPaymentOrder                │  │
│  │   • handleRazorpayWebhook             │  │
│  │   • verifyPickupCode                  │  │
│  │   • checkExpiredAuthorizations        │  │
│  └──────────────────┬────────────────────┘  │
└─────────────────────┼───────────────────────┘
                      │
              ┌───────┴────────┐
              │   Razorpay API │
              └────────────────┘
```

## Quick Start

### 1. Add Dependencies

**Flutter Plugin:**

```yaml
# pubspec.yaml
dependencies:
  razorpay_auth_capture:
    git:
      url: https://github.com/yourusername/razorpay-auth-capture.git
      path: flutter_package
```

**Firebase Functions:**

Copy the functions from `firebase_functions/` to your project's `functions/` directory.

### 2. Configure Environment

Create `.env` in your Flutter project root:

```env
RAZORPAY_KEY_ID=rzp_test_YOUR_KEY_HERE
```

Add to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - .env
```

### 3. Initialize Plugin

```dart
import 'package:razorpay_auth_capture/razorpay_auth_capture.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase first
  await Firebase.initializeApp();
  
  // Initialize Razorpay plugin
  final razorpay = RazorpayAuthCapture();
  await razorpay.initialize(RazorpayConfig(
    keyId: 'rzp_test_YOUR_KEY_HERE',
    merchantName: 'Your App Name',
    amount: 5000, // ₹50 in paise
  ));
  
  runApp(MyApp());
}
```

### 4. Use Pre-built Screens

**Option A: Use Plugin Screens (Recommended)**

```dart
// Receiver pays promise fee
RazorpayAuthCapture.showPaymentPrompt(
  context: context,
  donationId: 'donation_123',
  donorName: 'John Doe',
  itemTitle: 'Office Chair',
  userPhone: '+919876543210',
  userEmail: 'user@example.com',
  onSuccess: () {
    // Navigate to pickup code screen
    RazorpayAuthCapture.showPickupCode(
      context: context,
      transactionId: 'pay_xxxxx',
    );
  },
);

// Donor verifies pickup
RazorpayAuthCapture.showVerifyPickup(
  context: context,
  donationId: 'donation_123',
  receiverName: 'Jane Smith',
);
```

**Option B: Custom UI with Service API**

```dart
final paymentService = RazorpayAuthCapture().createPaymentService();

// Start payment
await paymentService.startPayment(
  donationId: 'donation_123',
  userPhone: '+919876543210',
  userEmail: 'user@example.com',
  onSuccess: (paymentId) {
    print('Payment authorized: $paymentId');
  },
  onError: (error) {
    print('Payment failed: $error');
  },
);

// Verify pickup code
final success = await paymentService.verifyPickupCode(
  donationId: 'donation_123',
  pickupCode: '7382',
);

// Listen to transaction updates
paymentService.getTransaction('pay_xxxxx').listen((transaction) {
  if (transaction != null) {
    print('Status: ${transaction.status}');
    print('Pickup Code: ${transaction.pickupCode}');
  }
});
```

## Backend Integration

### Firebase Functions

1. **Copy Functions**

   Copy files from `firebase_functions/src/` to your project's `functions/src/`

2. **Install Dependencies**

   ```bash
   cd functions
   npm install razorpay firebase-functions firebase-admin
   ```

3. **Deploy**

   ```bash
   firebase deploy --only functions
   ```

### Required Cloud Functions

The plugin requires these Cloud Functions:

| Function | Purpose |
|----------|---------|
| `createPaymentOrder` | Creates Razorpay order with auth-only |
| `handleRazorpayWebhook` | Receives payment events |
| `verifyPickupCode` | Validates pickup and voids payment |
| `checkExpiredAuthorizations` | Captures forfeited payments |

## Configuration Options

### RazorpayConfig

```dart
RazorpayConfig(
  keyId: 'rzp_test_...',           // Required: API Key
  merchantName: 'Your App',        // Required: Display name
  amount: 5000,                    // Optional: Amount in paise (default: 5000)
  currency: 'INR',                 // Optional: Currency (default: INR)
  description: 'Promise Fee',      // Optional: Payment description
  functionRegion: 'us-central1',   // Optional: Firebase region
  themeColor: '4CAF50',            // Optional: Checkout theme color
  enableUPI: true,                 // Optional: Enable UPI
  enableCards: true,               // Optional: Enable Cards
  enableNetbanking: true,          // Optional: Enable Netbanking
  enableWallets: true,             // Optional: Enable Wallets
)
```

## Customization

### Custom Payment Screen

```dart
class MyPaymentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final service = RazorpayAuthCapture().createPaymentService();
    
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _startPayment(service),
          child: Text('Pay ₹50'),
        ),
      ),
    );
  }
  
  void _startPayment(PaymentService service) {
    service.startPayment(
      donationId: 'my_donation_id',
      userPhone: '+919876543210',
      userEmail: 'user@example.com',
      onSuccess: (paymentId) => _handleSuccess(paymentId),
      onError: (error) => _handleError(error),
    );
  }
}
```

### Custom Theme

Override plugin screens with your theme:

```dart
Theme(
  data: Theme.of(context).copyWith(
    primaryColor: Colors.blue,
    // ... your custom theme
  ),
  child: PaymentPromptScreen(
    // ... params
  ),
)
```

## Database Schema

The plugin expects these Firestore collections:

```
collections/
├── donations/
│   └── {donationId}/
│       ├── status: "active" | "reserved" | "completed"
│       ├── donorId: string
│       ├── claimed_by: string
│       └── ...
│
├── transactions/
│   └── {paymentId}/
│       ├── donationId: string
│       ├── donorId: string
│       ├── receiverId: string
│       ├── payment_status: "authorized" | "captured" | "cancelled"
│       ├── pickup_code: string
│       ├── pickup_code_expires: timestamp
│       └── ...
│
└── idempotencyKeys/
    └── {key}/
        ├── orderId: string
        └── status: "created"
```

## Web Configuration

Add Razorpay script to `web/index.html`:

```html
<head>
  <!-- ... other head elements ... -->
  <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
</head>
```

## Testing

### Test Card

```
Card: 5267 3181 8797 5449
Expiry: 12/25
CVV: 123
```

### Simulate Webhook (Local)

```bash
cd functions/scripts
npx ts-node simulate_webhook.ts
```

## API Reference

### Classes

- `RazorpayAuthCapture` - Main plugin class
- `PaymentService` - Service for payments
- `RazorpayTransaction` - Transaction model
- `RazorpayConfig` - Configuration

### Enums

- `PaymentStatus` - authorized, captured, cancelled, expired, failed

### Callbacks

```dart
typedef PaymentSuccessCallback = void Function(String paymentId);
typedef PaymentErrorCallback = void Function(String error);
typedef PickupVerifyCallback = void Function(bool success, String? error);
```

## Troubleshooting

### Checkout Not Opening

- Check `.env` has correct `RAZORPAY_KEY_ID`
- Verify `web/index.html` has Razorpay script (for web)
- Check browser console for JS errors

### Webhook Not Working

- Use simulation script for local testing
- For production, configure webhook URL in Razorpay Dashboard
- Use ngrok to expose localhost

### Functions Not Deploying

- Check Firebase CLI is logged in
- Verify project is selected: `firebase use --add`
- Check `functions/package.json` dependencies

## Example Projects

See `example/` directory for complete working examples:
- `example/givelocally/` - Hyperlocal donation app
- `example/simple_payment/` - Minimal implementation

## License

MIT License - See LICENSE file

## Support

- GitHub Issues: https://github.com/yourusername/razorpay-auth-capture/issues
- Documentation: https://docs.yourdomain.com
