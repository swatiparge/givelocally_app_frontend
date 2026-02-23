# GiveLocally - Razorpay Promise Fee Integration

A Flutter application with Firebase backend implementing Razorpay's Authorization & Capture payment flow for a hyperlocal donation platform.

## Overview

This project implements a **Promise Fee (₹50)** system where:
- **Authorization**: Money is held (not deducted) when receiver claims an item
- **Void/Refund**: Money is released instantly upon successful pickup
- **Capture**: Money is forfeited if receiver doesn't show up within 24 hours

## Architecture

```
Flutter App (Web/Mobile)
    ↓
Firebase Cloud Functions
    ↓
Razorpay API (Orders & Payments)
```

### Key Components

- **Frontend**: Flutter with Razorpay Web SDK integration
- **Backend**: Firebase Cloud Functions (Node.js/TypeScript)
- **Database**: Cloud Firestore
- **Payment**: Razorpay (Authorization & Capture mode)

## Prerequisites

- **Flutter** (>=3.1.0)
- **Node.js** (>=18.0.0)
- **Firebase CLI**
- **Razorpay Account** (Test mode)

### Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

## Project Structure

```
givelocally/
├── lib/                          # Flutter application
│   ├── main.dart                 # App entry point
│   ├── payment/                  # Payment screens & service
│   │   ├── payment_service.dart
│   │   ├── payment_prompt_screen.dart
│   │   ├── pickup_code_screen.dart
│   │   └── ...
│   └── profile/                  # User profile & transactions
├── functions/                    # Firebase Cloud Functions
│   ├── src/
│   │   └── index.ts             # Backend functions
│   └── package.json
├── web/                         # Web configuration
│   └── index.html               # Includes Razorpay script
├── .env                         # Environment variables (not in git)
└── run_local_test.sh           # Helper script
```

## Setup Instructions


### How to Run the Flutter APP & Backend 

```bash 
flutter run -d chrome

```
### Backend

```bash

cd functions 
# start the emulator 
npm run serve 

# to test api use ngrok  -> to point webhook url 
 ngrok http 5001

# update webhook url in Razorpay 
https://0835dc25e66e.ngrok-free.app/demo-project/asia-southeast1/handleRazorpayWebhook
```

### 1. Clone and Install Dependencies

```bash
# Clone the repository
git clone <repository-url>
cd givelocally

# Install Flutter dependencies
flutter pub get

# Install backend dependencies
cd functions
npm install
cd ..
```

### 2. Configure Environment Variables

Create a `.env` file in the root directory:

```bash
# Copy the example file
cp .env.example .env
```

Edit `.env` and add your Razorpay Test Key:

```env
# Razorpay API Keys
# Get these from https://dashboard.razorpay.com/account/apikeys
RAZORPAY_KEY_ID=rzp_test_YOUR_ACTUAL_KEY_HERE

# Firebase Emulator Settings (for local testing)
USE_FIREBASE_EMULATOR=true
```

**Important**: Never commit the `.env` file to git!

### 3. Get Razorpay API Keys

1. Go to [Razorpay Dashboard](https://dashboard.razorpay.com/)
2. Switch to **Test Mode** (toggle at top right)
3. Go to **Settings** → **API Keys**
4. Copy the **Key ID** (starts with `rzp_test_`)
5. Paste it in your `.env` file

### 4. Set Up Firebase Emulators

Initialize Firebase in your project:

```bash
firebase init
```

Select:
- Firestore
- Functions
- Emulators (Firestore, Functions, Pub/Sub)

## Running the Application

### Option 1: Using the Helper Script

We provide a convenient script that starts everything:

```bash
chmod +x run_local_test.sh
./run_local_test.sh
```

This script will:
1. Install all dependencies
2. Start Firebase emulators
3. Provide instructions for running Flutter

### Option 2: Manual Setup

#### Step 1: Start Backend (Firebase Emulators)

```bash
cd functions
npm run serve
```

Or manually:

```bash
firebase emulators:start --only functions,firestore,pubsub
```

The emulators will be available at:
- **Firestore**: http://localhost:8080
- **Functions**: http://localhost:5001
- **Emulator UI**: http://localhost:4000

#### Step 2: Start Flutter App

In a new terminal:

```bash
# For Web (Recommended for testing)
flutter run -d chrome

# For Mobile
flutter run
```

## Testing the Payment Flow

### 1. Open the App

Navigate to the test screen: `Razorpay Flow Test`

### 2. Initiate Payment

Click **"1. Receiver: Pay Promise Fee"**

### 3. Complete Razorpay Checkout

Use test card details:
- **Card Number**: `5267 3181 8797 5449`
- **Expiry**: `12/25`
- **CVV**: `123`
- **Name**: Any name
- **UPI**: Use any test UPI ID (e.g., `test@upi`)

### 4. Simulate Webhook (Local Testing)

Since Razorpay can't reach your localhost, simulate the webhook:

```bash
cd functions/scripts
npx ts-node simulate_webhook.ts
```

This will:
- Send a `payment.authorized` event to your local function
- Create a transaction record in Firestore
- Generate a 4-digit pickup code

### 5. View Pickup Code

The receiver can now see the pickup code on the "Pickup Code Screen"

### 6. Complete Pickup (Donor)

Click **"Donor: Enter Pickup Code"** and enter the 4-digit code

This will:
- Verify the code
- Void the authorization (refund the ₹50)
- Mark donation as completed

## Backend Functions

### Cloud Functions

| Function | Type | Description |
|----------|------|-------------|
| `createPaymentOrder` | Callable | Creates Razorpay order with `payment_capture: 0` |
| `handleRazorpayWebhook` | HTTP | Receives payment.authorized/captured events |
| `verifyPickupCode` | Callable | Verifies pickup code and voids payment |
| `checkExpiredAuthorizations` | Scheduled | Runs every 10 min to capture forfeited payments |

### Testing Backend

```bash
cd functions

# Build TypeScript
npm run build

# Run emulators
npm run serve

# Deploy to production
npm run deploy
```

## Configuration Details

### Razorpay Settings

**Test Mode Configuration:**
- Authorization expiry: 24 hours
- Auto-capture: Disabled (`payment_capture: false`)
- Webhook URL: (Use ngrok for local testing)

### Firebase Emulators

**Ports:**
- Firestore: 8080
- Functions: 5001
- Pub/Sub: 8085
- Auth: 9099
- Emulator UI: 4000

### Web Configuration

The `web/index.html` includes the Razorpay script:

```html
<script src="https://checkout.razorpay.com/v1/checkout.js"></script>
```

## Troubleshooting

### Issue: Razorpay checkout doesn't open

**Solution:**
1. Check browser console for errors
2. Verify `RAZORPAY_KEY_ID` is set in `.env`
3. Ensure script is loaded in `web/index.html`
4. Hot restart (not just reload) the app

### Issue: Webhook not receiving events

**Solution:**
1. Use the simulation script for local testing
2. For production, use ngrok to expose localhost:
   ```bash
   ngrok http 5001
   ```
3. Update webhook URL in Razorpay Dashboard

### Issue: Functions not deploying

**Solution:**
1. Check Firebase CLI is logged in: `firebase login`
2. Verify project is selected: `firebase use --add`
3. Check `functions/package.json` has correct dependencies

## Testing with Real Razorpay (Optional)

1. Install ngrok:
   ```bash
   brew install ngrok
   ```

2. Expose local functions:
   ```bash
   ngrok http 5001
   ```

3. Copy the HTTPS URL (e.g., `https://abc123.ngrok.io`)

4. In Razorpay Dashboard:
   - Go to Settings → Webhooks
   - Add webhook URL: `https://abc123.ngrok.io/demo-project/asia-southeast1/handleRazorpayWebhook`
   - Select events: `payment.authorized`, `payment.captured`
   - Save and copy the webhook secret

5. Update `.env` in functions:
   ```env
   RAZORPAY_WEBHOOK_SECRET=your_webhook_secret
   ```

## Production Deployment

### Deploy Functions

```bash
cd functions
npm run deploy
```

### Deploy Web App

```bash
firebase deploy --only hosting
```

### Configure Environment Secrets

```bash
firebase functions:secrets:set RAZORPAY_KEY_ID
firebase functions:secrets:set RAZORPAY_KEY_SECRET
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
```

## Features

- ✅ Authorization & Capture payment flow
- ✅ Webhook handling with signature verification
- ✅ Pickup code generation and verification
- ✅ Automatic forfeiture for no-shows
- ✅ Transaction history
- ✅ UPI, Cards, Netbanking support
- ✅ Firebase emulator integration
- ✅ Web and Mobile support

## Tech Stack

- **Flutter** 3.1.0+
- **Dart** 3.0+
- **Firebase** (Functions, Firestore, Auth)
- **Razorpay** Node.js SDK
- **TypeScript** 5.3+

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Razorpay Documentation](https://razorpay.com/docs/)
- [Razorpay Test Cards](https://razorpay.com/docs/payments/payments/test-card-details/)

## License

This project is for educational purposes.

## Support

For issues or questions, please check:
1. Browser console for frontend errors
2. Firebase emulator logs for backend errors
3. Razorpay dashboard for payment status
