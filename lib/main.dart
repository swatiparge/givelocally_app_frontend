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
import 'screens/home/home_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'dart:io';
import 'navigation/route_observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: MaterialApp(
        title: 'GiveLocally',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [routeObserver],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/home': (context) => HomeScreen(), // Removed const
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
