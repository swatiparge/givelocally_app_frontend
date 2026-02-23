import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:givelocally_app/config/environment.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/donation/food_donation_screen.dart';
import 'screens/donation/appliances_donation_screen.dart';
import 'screens/donation/blood_request_screen.dart';
import 'screens/donation/stationery_donation_screen.dart';
import 'screens/home/donation_detail_screen.dart';
import 'screens/home/reserve_item_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';


  import 'dart:io';

import 'navigation/route_observer.dart';

// ============================================
// MAIN ENTRY POINT
// ============================================

// void main() async {
//   // Ensure flutter is initialized
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // Init Firebase
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   // Initialize App Check for physical devices
//   // FIXED: Use Debug Provider for physical device development
//   await FirebaseAppCheck.instance.activate(
//     androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
//     appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
//   );
//   // Configure emulators for development
//   if (kDebugMode && Environment.useEmulator) {
//     debugPrint('🔧 Configuring Firebase Emulators...');
//
//     // Auth Emulator - Port 9099
//     try {
//       if (Platform.isIOS) {
//         await FirebaseAuth.instance.setSettings(
//           appVerificationDisabledForTesting: true,
//         );
//         debugPrint('✅ iOS app verification disabled for testing');
//       }
//
//       await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
//       debugPrint('✅ Auth Emulator configured: 127.0.0.1:9099');
//
//     } catch (e) {
//       debugPrint('⚠️  Auth Emulator error (might be already configured): $e');
//     }
//   } else {
//     debugPrint('🚀 Using Firebase Production');
//   }
//
//   // Run app
//   runApp(const MyApp());
// }

//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // 1️⃣ Initialize Firebase
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//
//   // 2️⃣ Enable App Check (NO emulators)
//   await FirebaseAppCheck.instance.activate(
//     androidProvider:
//     kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
//     appleProvider:
//     kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
//   );
//
//   // 3️⃣ Run the app
//   runApp(const MyApp());
// }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

// ============================================
// ROOT WIDGET
// ============================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // State Management providers
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: MaterialApp(
        title: 'GiveLocally',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [routeObserver],

        // Theme (Material Design 3)
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        ),

        // Routes section
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/post-food': (context) => const FoodDonationScreen(),
          '/post-appliances': (context) => const AppliancesDonationScreen(),
          '/post-blood': (context) => const BloodRequestScreen(),
          '/post-stationery': (context) => const StationeryDonationScreen(),

          '/donation-detail': (context) {
            final Map<String, dynamic> donation = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return DonationDetailScreen(donation: donation);
          },
          
          '/reserve-item': (context) {
            final Map<String, dynamic> donation = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return ReserveItemScreen(donation: donation);
          },
        },
      ),
    );
  }
}
