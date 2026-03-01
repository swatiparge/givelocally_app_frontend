import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/navigation_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    // Add a small delay for branding/splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Use Riverpod to access AuthService
    final authService = ref.read(authServiceProvider);
    final String nextStep = await authService.getNextStep();

    if (!mounted) return;

    if (nextStep == '/home') {
      // Using GoRouter navigation
      context.goHome();
    } else if (nextStep == '/location-setup') {
      context.goLocationSetup();
    } else {
      context.goPhoneLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Placeholder
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.volunteer_activism,
                size: 60,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "GiveLocally",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1C1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Connecting neighbors, sharing kindness",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
