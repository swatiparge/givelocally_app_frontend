import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_check_config.dart';
import 'routes/app_router.dart';
import 'services/fcm_service.dart';
import 'providers/preferences_provider.dart';
import 'firebase_options.dart';
import 'widgets/notification_listener_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ Step 1: WidgetsBinding initialized');

  try {
    // Robust Firebase Initialization
    try {
      // Try to get existing app first
      Firebase.app();
      debugPrint('✅ Step 2: Firebase already initialized (via app())');
    } catch (_) {
      // If no app exists, initialize it
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Step 2: Firebase initialized (Success)');
      } catch (e) {
        // Broad catch for duplicate-app or other initialization errors
        if (e.toString().contains('duplicate-app')) {
          debugPrint(
            '⚠️ Step 2: Firebase already initialized (Caught duplicate)',
          );
        } else {
          debugPrint('❌ Step 2: Firebase initialization failed with: $e');
          rethrow;
        }
      }
    }

    // Initialize SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    debugPrint('✅ Step 3: SharedPreferences initialized');

    // Initialize App Check
    await AppCheckConfig.initialize();
    debugPrint('✅ Step 4: App Check initialized');

    // Initialize FCM with error handling (non-blocking)
    try {
      await FcmService().initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Step 5: FCM initialization timed out');
        },
      );
      debugPrint('✅ Step 5: FCM initialized');
    } catch (e) {
      debugPrint('⚠️ Step 5: FCM failed (non-fatal): $e');
    }

    debugPrint('✅ Step 6: Starting app...');
    runApp(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MyApp(),
      ),
    );
    debugPrint('✅ Step 7: App started successfully');
  } catch (e, stackTrace) {
    debugPrint('🔥 FATAL ERROR: $e');
    debugPrint('Stack: $stackTrace');

    // Attempt to show error on screen if possible
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Fatal App Initialization Error',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(e.toString(), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('🏗️ Building MyApp...');

    return NotificationListenerWidget(
      child: MaterialApp.router(
        title: 'GiveLocally',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: FcmService.messengerKey,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        ),
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
