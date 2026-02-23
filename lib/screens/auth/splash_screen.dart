import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'phone_login_screen.dart';
import 'package:givelocally_app/screens/home/home_screen.dart';


// ============================================
// SPLASH SCREEN (WF-01 - Part 1)
// Shows logo, checks auth state, redirects
// ============================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  // ==========================================
  // CHECK AUTH STATE AND NAVIGATE
  // ==========================================
  
  Future<void> _checkAuthAndNavigate() async {
    // Wait 2 seconds (show splash)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if user is logged in
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User logged in → Go to Home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } else {
      // Not logged in → Go to Login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const PhoneLoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50), // Primary green
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo (placeholder - you'll add real logo later)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.volunteer_activism,
                size: 64,
                color: Color(0xFF4CAF50),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // App name
            const Text(
              'GiveLocally',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Tagline
            const Text(
              'Give locally, impact globally',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Loading indicator
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
