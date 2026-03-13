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
import '../screens/auth/otp_screen.dart';
import '../screens/auth/location_confirmation_screen.dart';
import '../screens/home/view_all_donations_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../services/fcm_service.dart';

// Export for convenience
export '../services/fcm_service.dart';

/// Provider for the GoRouter instance
final routerProvider = Provider<GoRouter>((ref) {
  // Use ref.read instead of ref.watch to prevent re-creating the GoRouter instance
  // when authService notifies listeners (e.g., during loading state changes).
  // GoRouter uses refreshListenable to handle redirects on its own.
  final authService = ref.read(authServiceProvider);

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRouter.splash,
    navigatorKey: FcmService.navigatorKey,
    refreshListenable: authService,

    redirect: (context, state) {
      final isLoggedIn = authService.isAuthenticated;
      final path = state.uri.path;
      final isAuthRoute = path == AppRouter.phoneLogin || path == AppRouter.otp;
      final isSplash = path == AppRouter.splash;

      if (!isLoggedIn && !isAuthRoute && !isSplash) {
        return AppRouter.phoneLogin;
      }
      if (isLoggedIn && (isAuthRoute || isSplash)) {
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
        path: AppRouter.otp,
        name: 'otp',
        builder: (context, state) {
          final phoneNumber = state.extra as String? ?? '';
          return OTPScreen(phoneNumber: phoneNumber);
        },
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
        path: AppRouter.viewAllDonations,
        name: 'viewAllDonations',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          if (args == null) {
            return const Scaffold(
              body: Center(
                child: Text('View all donations: Missing parameters'),
              ),
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
      GoRoute(
        path: AppRouter.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRouter.chat,
        name: 'chat',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          if (args == null) {
            return const Scaffold(
              body: Center(child: Text('Chat: Missing parameters')),
            );
          }
          return ChatScreen(
            donationId: args['donationId'] ?? '',
            itemName: args['itemName'] ?? 'Item',
            itemImage: args['itemImage'],
            requesterId: args['requesterId'],
          );
        },
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
  static const String otp = '/otp';
  static const String locationSetup = '/location-setup';
  static const String postFood = '/post-food';
  static const String postAppliances = '/post-appliances';
  static const String postBlood = '/post-blood';
  static const String postStationery = '/post-stationery';
  static const String donationDetail = '/donation-detail';
  static const String reserveItem = '/reserve-item';
  static const String viewAllDonations = '/view-all-donations';
  static const String notifications = '/notifications';
  static const String chat = '/chat/:donationId';

  AppRouter._();
}

extension GoRouterContext on BuildContext {
  void goToHome() => go(AppRouter.home);
  void goToSplash() => go(AppRouter.splash);
  void goToPostFood() => go(AppRouter.postFood);
  void goToPostAppliances() => go(AppRouter.postAppliances);
  void goToPostBlood() => go(AppRouter.postBlood);
  void goToPostStationery() => go(AppRouter.postStationery);

  void goToOTP(String phoneNumber) {
    push(AppRouter.otp, extra: phoneNumber);
  }

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

  void goToNotifications() => push(AppRouter.notifications);

  void goToChat({
    required String donationId,
    required String itemName,
    String? itemImage,
    String? requesterId,
  }) {
    push(
      AppRouter.chat.replaceFirst(':donationId', donationId),
      extra: {
        'donationId': donationId,
        'itemName': itemName,
        'itemImage': itemImage,
        'requesterId': requesterId,
      },
    );
  }
}
