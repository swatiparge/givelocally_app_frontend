import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
// REMOVED: App Check interferes with Firebase Auth reCAPTCHA
// import 'config/app_check_config.dart';
import 'routes/app_router.dart';
import 'services/fcm_service.dart';
import 'providers/preferences_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ Step 1: WidgetsBinding initialized');

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
      debugPrint('✅ Step 2: Firebase initialized');
    }

    // Initialize SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    debugPrint('✅ Step 3: SharedPreferences initialized');

    // REMOVED: App Check initialization - it blocks Firebase Auth reCAPTCHA
    // App Check will be added later after OTP flow is working
    // See: https://github.com/firebase/flutterfire/issues/11914

    // Initialize FCM with error handling (non-blocking)
    try {
      await FcmService().initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Step 4: FCM initialization timed out');
        },
      );
      debugPrint('✅ Step 4: FCM initialized');
    } catch (e) {
      debugPrint('⚠️ Step 4: FCM failed (non-fatal): $e');
      // Continue without FCM - OTP should still work
    }

    debugPrint('✅ Step 5: Starting app...');
    runApp(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MyApp(),
      ),
    );
    debugPrint('✅ Step 6: App started successfully');
  } catch (e, stackTrace) {
    debugPrint('🔥 FATAL ERROR: $e');
    debugPrint('Stack: $stackTrace');
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('Error: $e'))),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('🏗️ Building MyApp...');

    return MaterialApp.router(
      title: 'GiveLocally',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
