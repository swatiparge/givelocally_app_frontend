# Razorpay Auth Capture Plugin

[![Pub Version](https://img.shields.io/pub/v/razorpay_auth_capture)](https://pub.dev/packages/razorpay_auth_capture)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A **pluggable** Flutter plugin for implementing Razorpay's Authorization & Capture payment flow. Perfect for apps that need to hold money as a "Promise Fee" and release it upon successful completion.

## 🎯 Use Cases

- **Rental Apps** - Security deposits that get refunded
- **Marketplaces** - Buyer protection with promise fees
- **Delivery Apps** - No-show protection for drivers
- **Donation Apps** - Hold fees to prevent fake pickups (like GiveLocally)
- **Appointment Booking** - Cancellation fees

## ✨ Features

- 🔒 **Authorization & Capture** - Hold money without deducting
- 🌐 **Cross-Platform** - Web, iOS, Android
- 🔥 **Firebase Backend** - Ready-to-use Cloud Functions
- 📦 **Plug & Play** - Easy integration into existing projects
- 💳 **Multiple Methods** - UPI, Cards, Netbanking, Wallets
- 🔢 **Pickup Code System** - Built-in verification flow
- 📊 **Transaction Tracking** - Real-time status updates

## 📦 Installation

### 1. Flutter Plugin

```yaml
# pubspec.yaml
dependencies:
  razorpay_auth_capture: ^1.0.0
```

Or from GitHub:

```yaml
dependencies:
  razorpay_auth_capture:
    git:
      url: https://github.com/yourusername/razorpay-auth-capture.git
      path: razorpay_plugin/flutter_package
```

### 2. Firebase Functions

Copy the backend functions to your project:

```bash
# Copy functions
cp -r razorpay_plugin/firebase_functions/* your_project/functions/

# Install dependencies
cd your_project/functions
npm install

# Deploy
firebase deploy --only functions
```

## 🚀 Quick Start

### Step 1: Configure

Create `.env` file:

```env
RAZORPAY_KEY_ID=rzp_test_YOUR_KEY_HERE
```

### Step 2: Initialize

```dart
import 'package:razorpay_auth_capture/razorpay_auth_capture.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize plugin
  await RazorpayAuthCapture().initialize(RazorpayConfig(
    keyId: 'rzp_test_YOUR_KEY_HERE',
    merchantName: 'Your App',
    amount: 5000, // ₹50 in paise
  ));
  
  runApp(MyApp());
}
```

### Step 3: Use

```dart
// Show payment screen
RazorpayAuthCapture.showPaymentPrompt(
  context: context,
  donationId: 'item_123',
  donorName: 'John Doe',
  itemTitle: 'Office Chair',
  userPhone: '+919876543210',
  userEmail: 'user@example.com',
  onSuccess: () {
    // Navigate to pickup code
  },
);
```

## 📁 Plugin Structure

```
razorpay_plugin/
├── flutter_package/          # Flutter Plugin
│   ├── lib/
│   │   ├── src/
│   │   │   ├── razorpay_auth_capture_base.dart
│   │   │   ├── payment_service.dart
│   │   │   ├── razorpay_service_web.dart
│   │   │   └── razorpay_service_mobile.dart
│   │   ├── screens/
│   │   │   ├── payment_prompt_screen.dart
│   │   │   ├── pickup_code_screen.dart
│   │   │   └── verify_pickup_screen.dart
│   │   ├── models/
│   │   │   └── payment_models.dart
│   │   └── razorpay_auth_capture.dart
│   └── pubspec.yaml
│
├── firebase_functions/       # Backend Functions
│   ├── src/
│   │   ├── index.ts
│   │   ├── createPaymentOrder.ts
│   │   ├── handleWebhook.ts
│   │   ├── verifyPickupCode.ts
│   │   └── checkExpired.ts
│   └── package.json
│
├── docs/
│   └── INTEGRATION.md       # Detailed integration guide
│
└── example/
    ├── givelocally/         # Example app
    └── simple_payment/      # Minimal example
```

## 🔌 Integration Options

### Option 1: Pre-built Screens (Easiest)

```dart
// Just show the screens
RazorpayAuthCapture.showPaymentPrompt(...)
RazorpayAuthCapture.showPickupCode(...)
RazorpayAuthCapture.showVerifyPickup(...)
```

### Option 2: Custom UI + Service API

```dart
final service = RazorpayAuthCapture().createPaymentService();

// Your custom UI
ElevatedButton(
  onPressed: () => service.startPayment(
    donationId: 'my_id',
    userPhone: phone,
    userEmail: email,
    onSuccess: (id) => handleSuccess(id),
    onError: (e) => handleError(e),
  ),
  child: Text('Pay'),
)
```

### Option 3: Backend Only

Use just the Firebase functions in any project:

```javascript
// Your existing Cloud Function
const { createPaymentOrder } = require('razorpay-auth-capture/functions');

exports.myCustomFunction = functions.https.onCall(async (data, context) => {
  // Your custom logic
  
  // Use plugin's payment creation
  const order = await createPaymentOrder(data.donationId, context.auth.uid);
  
  // More custom logic
  return order;
});
```

## 🎨 Customization

### Theme Configuration

```dart
RazorpayConfig(
  keyId: 'rzp_test_...',
  merchantName: 'Your App',
  themeColor: 'FF5733', // Custom color
  enableUPI: true,
  enableCards: true,
  // ... other options
)
```

### Custom Screens

Override with your own UI:

```dart
Theme(
  data: yourTheme,
  child: PaymentPromptScreen(
    donationId: id,
    donorName: name,
    itemTitle: title,
    userPhone: phone,
    userEmail: email,
    onSuccess: onSuccess,
    onCancel: onCancel,
  ),
)
```

## 📊 Payment Flow

```
1. Receiver clicks "Pay Promise Fee"
   ↓
2. Razorpay Checkout opens
   ↓
3. User completes payment
   ↓
4. Money is HELD (not deducted)
   ↓
5. Webhook creates transaction
   ↓
6. Pickup code generated
   ↓
7. Receiver shows code to Donor
   ↓
8. Donor verifies code
   ↓
9. Money is RELEASED (voided)
   ↓
10. Transaction complete!

If no-show within 24h:
   ↓
Money is CAPTURED (forfeited)
```

## 🧪 Testing

### Test Card

```
Number: 5267 3181 8797 5449
Expiry: 12/25
CVV: 123
```

### Local Development

```bash
# Start emulators
firebase emulators:start --only functions,firestore

# Run Flutter app
flutter run -d chrome

# Simulate webhook
cd functions/scripts
npx ts-node simulate_webhook.ts
```

## 📖 Documentation

- [Integration Guide](docs/INTEGRATION.md) - Detailed setup instructions
- [API Reference](docs/API.md) - Complete API documentation
- [Testing Guide](docs/TESTING.md) - How to test all scenarios
- [Example Apps](example/) - Working example projects

## 🔧 Backend Requirements

### Cloud Functions

| Function | Trigger | Purpose |
|----------|---------|---------|
| `createPaymentOrder` | Callable | Creates Razorpay order |
| `handleRazorpayWebhook` | HTTP | Receives payment events |
| `verifyPickupCode` | Callable | Validates & voids payment |
| `checkExpiredAuthorizations` | Scheduled | Captures forfeited fees |

### Firestore Collections

```
donations/{id}          - Your items/transactions
transactions/{id}       - Payment records
idempotencyKeys/{id}    - Duplicate prevention
```

## 🐛 Troubleshooting

**Checkout not opening?**
- Check `RAZORPAY_KEY_ID` in `.env`
- For web: Check script in `web/index.html`
- Check browser console for errors

**Webhook not working?**
- Use simulation script locally
- For production: Use ngrok or deploy functions

**Functions failing?**
- Check Firebase CLI is logged in
- Verify Razorpay keys in function environment

## 💡 Examples

### E-commerce App

```dart
// Hold payment until order delivered
RazorpayAuthCapture.showPaymentPrompt(
  context: context,
  donationId: 'order_123',  // Use order ID
  donorName: 'Seller Name',
  itemTitle: 'Product Name',
  userPhone: buyerPhone,
  userEmail: buyerEmail,
  onSuccess: () {
    // Show pickup/delivery code
  },
);
```

### Rental App

```dart
// Security deposit
await RazorpayAuthCapture().initialize(RazorpayConfig(
  keyId: key,
  merchantName: 'RentalApp',
  amount: 10000, // ₹100 deposit
  description: 'Security Deposit',
));
```

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md)

## 📄 License

MIT License - see [LICENSE](LICENSE) file

## 🙏 Credits

Built with:
- [Razorpay](https://razorpay.com/)
- [Flutter](https://flutter.dev/)
- [Firebase](https://firebase.google.com/)

---

**Need Help?**
- 📧 Email: support@yourdomain.com
- 💬 Discord: [Join our server](https://discord.gg/xyz)
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/razorpay-auth-capture/issues)
