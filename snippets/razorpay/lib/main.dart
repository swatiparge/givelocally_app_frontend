import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Local payment screens (working implementation)
import 'payment/payment_prompt_screen.dart';
import 'payment/pickup_code_screen.dart';
import 'payment/verification_expired_screen.dart';
import 'payment/verification_success_screen.dart';
import 'payment/verify_pickup_code_screen.dart';
import 'profile/transaction_history_screen.dart';
import 'firebase_options.dart';

// PLUGIN INTEGRATION (When ready):
// The razorpay_plugin package structure is created but needs import fixes.
// For now, use the local implementation above which works perfectly.
// import 'package:razorpay_auth_capture/razorpay_auth_capture.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
  );

  // PLUGIN INITIALIZATION (When plugin is ready):
  // Uncomment below to use the razorpay_auth_capture plugin
  /*
  final razorpayKey = dotenv.env['RAZORPAY_KEY_ID'] ?? '';
  if (razorpayKey.isNotEmpty && razorpayKey != 'rzp_test_YOUR_KEY_ID_HERE') {
    await RazorpayAuthCapture().initialize(RazorpayConfig(
      keyId: razorpayKey,
      merchantName: 'GiveLocally',
      amount: 5000, // ₹50 in paise
      description: 'Promise Fee (Refundable)',
      functionRegion: 'asia-southeast1',
      themeColor: '4CAF50',
      enableUPI: true,
      enableCards: true,
      enableNetbanking: true,
      enableWallets: true,
    ));
    debugPrint('✅ RazorpayAuthCapture plugin initialized');
  } else {
    debugPrint('⚠️ Razorpay key not configured. Payment features disabled.');
  }
  */

  if (kDebugMode) {
    debugPrint('🔧 Configuring Firebase Emulators...');

    try {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).useFunctionsEmulator('localhost', 5001);
      print('Using Firebase Emulators');
    } catch (e) {
      print('Error configuring emulators: $e');
    }
  }

  runApp(const GiveLocallyApp());
}

class GiveLocallyApp extends StatelessWidget {
  const GiveLocallyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GiveLocally Payment Test',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const TestHomeScreen(),
      routes: {
        '/payment-prompt': (context) => const PaymentPromptScreen(
              donationId: 'test_donation_123',
              donorName: 'Test Donor',
              itemTitle: 'Test Item',
            ),
        '/verification-success': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return VerificationSuccessScreen(donationId: args['donationId']);
        },
        '/verification-expired': (context) => const VerificationExpiredScreen(),
        '/transaction-history': (context) => const TransactionHistoryScreen(),
      },
    );
  }
}

class TestHomeScreen extends StatelessWidget {
  const TestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Razorpay Flow Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Payment Flow'),
          _buildNavButton(
            context,
            '1. Receiver: Pay Promise Fee',
            '/payment-prompt',
          ),
          const Divider(height: 32),
          _buildSectionHeader('Donor Actions'),
          _buildNavButton(
            context,
            'Donor: Enter Pickup Code',
            '/verify-pickup',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VerifyPickupCodeScreen(
                    donationId: 'test_donation_123',
                    receiverName: 'Test Receiver',
                  ),
                ),
              );
            },
          ),
          _buildNavButton(
            context,
            'Receiver: View Pickup Code',
            '/pickup-code',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Check Firestore for transaction ID'),
                ),
              );
            },
          ),
          const Divider(height: 32),
          _buildSectionHeader('Profile'),
          _buildNavButton(
            context,
            'Transaction History',
            '/transaction-history',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    String label,
    String route, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: onTap ?? () => Navigator.pushNamed(context, route),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(label),
      ),
    );
  }
}
