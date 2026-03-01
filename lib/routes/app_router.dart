import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/donation/food_donation_screen.dart';
import '../screens/donation/appliances_donation_screen.dart';
import '../screens/donation/blood_request_screen.dart';
import '../screens/donation/stationery_donation_screen.dart';
import '../screens/home/donation_detail_screen.dart';
import '../screens/home/reserve_item_screen.dart';
import '../screens/auth/phone_login_screen.dart';
import '../screens/auth/location_confirmation_screen.dart';
import '../screens/home/view_all_donations_screen.dart';

/// Provider for the GoRouter instance
final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRouter.splash,
    refreshListenable: authService,

    redirect: (context, state) {
      final isLoggedIn = authService.isAuthenticated;
      final isLoggingIn = state.uri.path == AppRouter.phoneLogin;
      final isSplash = state.uri.path == AppRouter.splash;

      if (!isLoggedIn && !isLoggingIn && !isSplash) {
        return AppRouter.phoneLogin;
      }
      if (isLoggedIn && (isLoggingIn || isSplash)) {
        return AppRouter.home;
      }
      return null;
    },

    routes: [
      GoRoute(
        path: AppRouter.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRouter.phoneLogin,
        name: 'phoneLogin',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: AppRouter.locationSetup,
        name: 'locationSetup',
        builder: (context, state) => const LocationConfirmationScreen(),
      ),
      GoRoute(
        path: AppRouter.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRouter.postFood,
        name: 'postFood',
        builder: (context, state) => const FoodDonationScreen(),
      ),
      GoRoute(
        path: AppRouter.postAppliances,
        name: 'postAppliances',
        builder: (context, state) => const AppliancesDonationScreen(),
      ),
      GoRoute(
        path: AppRouter.postBlood,
        name: 'postBlood',
        builder: (context, state) => const BloodRequestScreen(),
      ),
      GoRoute(
        path: AppRouter.postStationery,
        name: 'postStationery',
        builder: (context, state) => const StationeryDonationScreen(),
      ),
      GoRoute(
        path: AppRouter.donationDetail,
        name: 'donationDetail',
        builder: (context, state) {
          final donation = state.extra as Map<String, dynamic>?;
          if (donation == null) {
            return const Scaffold(
              body: Center(child: Text('Donation data not found')),
            );
          }
          return DonationDetailScreen(donation: donation);
        },
      ),
      GoRoute(
        path: AppRouter.reserveItem,
        name: 'reserveItem',
        builder: (context, state) {
          final donation = state.extra as Map<String, dynamic>?;
          if (donation == null) {
            return const Scaffold(
              body: Center(child: Text('Donation data not found')),
            );
          }
          return ReserveItemScreen(donation: donation);
        },
      ),
      GoRoute(
        path: AppRouter.viewAllDonations,
        name: 'viewAllDonations',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          if (args == null) {
            return const Scaffold(
              body: Center(child: Text('View all donations: Missing parameters')),
            );
          }
          return ViewAllDonationsScreen(
            title: args['title'] ?? 'Donations',
            category: args['category'] ?? '',
            categories: args['categories'] as List<String>?,
            lat: args['lat'] as double,
            lng: args['lng'] as double,
          );
        },
      ),
    ],

    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '404 - Page Not Found',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('Route: ${state.uri.path}'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRouter.splash),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    },
  );
});

class AppRouter {
  static const String splash = '/';
  static const String home = '/home';
  static const String phoneLogin = '/phone-login';
  static const String locationSetup = '/location-setup';
  static const String postFood = '/post-food';
  static const String postAppliances = '/post-appliances';
  static const String postBlood = '/post-blood';
  static const String postStationery = '/post-stationery';
  static const String donationDetail = '/donation-detail';
  static const String reserveItem = '/reserve-item';
  static const String viewAllDonations = '/view-all-donations';

  AppRouter._();
}

extension GoRouterContext on BuildContext {
  void goToHome() => go(AppRouter.home);
  void goToSplash() => go(AppRouter.splash);
  void goToPostFood() => go(AppRouter.postFood);
  void goToPostAppliances() => go(AppRouter.postAppliances);
  void goToPostBlood() => go(AppRouter.postBlood);
  void goToPostStationery() => go(AppRouter.postStationery);

  void goToDonationDetail(Map<String, dynamic> donation) {
    push(AppRouter.donationDetail, extra: donation);
  }

  void goToReserveItem(Map<String, dynamic> donation) {
    push(AppRouter.reserveItem, extra: donation);
  }

  void goToViewAll({
    required String title,
    required String category,
    List<String>? categories,
    required double lat,
    required double lng,
  }) {
    push(
      AppRouter.viewAllDonations,
      extra: {
        'title': title,
        'category': category,
        'categories': categories,
        'lat': lat,
        'lng': lng,
      },
    );
  }
}
