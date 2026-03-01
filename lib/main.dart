import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  // Wrap app with ProviderScope for Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

/// Main App Widget with Riverpod + GoRouter
///
/// Phase 5: State Management Migration
/// - Using Riverpod for state management
/// - GoRouter for declarative navigation
/// - Deep linking support enabled
/// - Type-safe routes with constants
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'GiveLocally',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      // Use GoRouter from Riverpod provider
      routerConfig: router,
    );
  }
}
