// lib/services/navigation_service.dart
// Navigation Service - Bridge between old and new navigation
//
// Phase 4: Navigation Migration Strategy
// This service allows gradual migration from Navigator.push to GoRouter
//
// Usage:
// OLD: Navigator.pushNamed(context, '/home')
// NEW: NavigationService.to(context).goHome()
//
// Or use GoRouter directly:
// context.go('/home')

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigation Service for smooth transition between navigation systems
///
/// This service provides a unified API while migrating from Material Navigation
/// to GoRouter. Once migration is complete, this service can be deprecated
/// in favor of direct GoRouter usage.
class NavigationService {
  static NavigationService? _instance;
  static NavigationService get instance {
    _instance ??= NavigationService._();
    return _instance!;
  }

  NavigationService._();

  /// Get navigation methods for a specific context
  static NavigationHelper to(BuildContext context) {
    return NavigationHelper(context);
  }

  /// Get the current route path
  static String? currentPath(BuildContext context) {
    return GoRouterState.of(context).uri.toString();
  }

  /// Check if a specific route is active
  static bool isRouteActive(BuildContext context, String route) {
    return GoRouterState.of(context).uri.toString() == route;
  }
}

/// Helper class for navigation within a specific BuildContext
///
/// Provides both imperative (old-style) and declarative (new-style) navigation
class NavigationHelper {
  final BuildContext _context;

  NavigationHelper(this._context);

  // ==================== AUTH NAVIGATION ====================

  void goSplash() => _context.go('/');
  void pushSplash() => _context.push('/');
  void replaceSplash() => _context.replace('/');

  void goPhoneLogin() => _context.go('/phone-login');
  void pushPhoneLogin() => _context.push('/phone-login');
  void replacePhoneLogin() => _context.replace('/phone-login');

  void goLocationSetup() => _context.go('/location-setup');
  void pushLocationSetup() => _context.push('/location-setup');
  void replaceLocationSetup() => _context.replace('/location-setup');

  // ==================== HOME NAVIGATION ====================

  void goHome() => _context.go('/home');
  void pushHome() => _context.push('/home');
  void replaceHome() => _context.replace('/home');

  // ==================== DONATION POSTING ====================

  void goPostFood() => _context.go('/post-food');
  void pushPostFood() => _context.push('/post-food');

  void goPostAppliances() => _context.go('/post-appliances');
  void pushPostAppliances() => _context.push('/post-appliances');

  void goPostBlood() => _context.go('/post-blood');
  void pushPostBlood() => _context.push('/post-blood');

  void goPostStationery() => _context.go('/post-stationery');
  void pushPostStationery() => _context.push('/post-stationery');

  // ==================== DETAIL NAVIGATION ====================

  /// Navigate to donation detail with data
  ///
  /// Example:
  /// ```dart
  /// NavigationService.to(context).goDonationDetail(myDonation);
  /// ```
  void goDonationDetail(Map<String, dynamic> donation) {
    _context.go('/donation-detail', extra: donation);
  }

  void pushDonationDetail(Map<String, dynamic> donation) {
    _context.push('/donation-detail', extra: donation);
  }

  void goReserveItem(Map<String, dynamic> donation) {
    _context.go('/reserve-item', extra: donation);
  }

  void pushReserveItem(Map<String, dynamic> donation) {
    _context.push('/reserve-item', extra: donation);
  }

  // ==================== UTILITY METHODS ====================

  /// Go back (pop)
  void back() => _context.pop();

  /// Go back with result
  void backWithResult<T>(T result) => _context.pop(result);

  /// Check if can pop
  bool canPop() => Navigator.canPop(_context);

  /// Navigate to specific path
  void go(String path, {Object? extra}) => _context.go(path, extra: extra);
  void push(String path, {Object? extra}) => _context.push(path, extra: extra);
  void replace(String path, {Object? extra}) =>
      _context.replace(path, extra: extra);

  /// Navigate to named route
  void goNamed(
    String name, {
    Map<String, String> params = const {},
    Object? extra,
  }) {
    _context.goNamed(name, pathParameters: params, extra: extra);
  }

  void pushNamed(
    String name, {
    Map<String, String> params = const {},
    Object? extra,
  }) {
    _context.pushNamed(name, pathParameters: params, extra: extra);
  }

  // ==================== MIGRATION HELPERS ====================

  /// Legacy compatibility: Navigate using old route names
  ///
  /// Use this temporarily when migrating code that uses string routes
  /// @deprecated Migrate to typed navigation methods
  void legacyGo(String route, {Object? arguments}) {
    switch (route) {
      case '/':
        goSplash();
        break;
      case '/home':
        goHome();
        break;
      case '/post-food':
        goPostFood();
        break;
      case '/post-appliances':
        goPostAppliances();
        break;
      case '/post-blood':
        goPostBlood();
        break;
      case '/post-stationery':
        goPostStationery();
        break;
      case '/donation-detail':
        if (arguments is Map<String, dynamic>) {
          goDonationDetail(arguments);
        }
        break;
      case '/reserve-item':
        if (arguments is Map<String, dynamic>) {
          goReserveItem(arguments);
        }
        break;
      default:
        _context.go(route);
    }
  }
}

/// Extension methods for BuildContext
///
/// Provides shorthand navigation methods directly on BuildContext
///
/// Usage:
/// ```dart
/// context.goHome();
/// context.goDonationDetail(donation);
/// ```
extension BuildContextNavigation on BuildContext {
  // Auth navigation
  void goSplash() => NavigationService.to(this).goSplash();
  void replaceSplash() => NavigationService.to(this).replaceSplash();
  void goPhoneLogin() => NavigationService.to(this).goPhoneLogin();
  void replacePhoneLogin() => NavigationService.to(this).replacePhoneLogin();
  void goLocationSetup() => NavigationService.to(this).goLocationSetup();
  void replaceLocationSetup() =>
      NavigationService.to(this).replaceLocationSetup();

  // Home navigation
  void goHome() => NavigationService.to(this).goHome();

  // Post navigation
  void goPostFood() => NavigationService.to(this).goPostFood();
  void goPostAppliances() => NavigationService.to(this).goPostAppliances();
  void goPostBlood() => NavigationService.to(this).goPostBlood();
  void goPostStationery() => NavigationService.to(this).goPostStationery();

  // Detail navigation
  void goDonationDetail(Map<String, dynamic> donation) =>
      NavigationService.to(this).goDonationDetail(donation);
  void goReserveItem(Map<String, dynamic> donation) =>
      NavigationService.to(this).goReserveItem(donation);

  // Back navigation
  void back() => NavigationService.to(this).back();
  void backWithResult<T>(T result) =>
      NavigationService.to(this).backWithResult(result);
}

/// Migration Guide from Material Navigation to GoRouter:
///
/// 1. Replace Navigator.pushNamed:
///    OLD: Navigator.pushNamed(context, '/home')
///    NEW: context.goHome() or NavigationService.to(context).goHome()
///
/// 2. Replace Navigator.push with arguments:
///    OLD: Navigator.pushNamed(context, '/donation-detail', arguments: donation)
///    NEW: context.goDonationDetail(donation)
///
/// 3. Replace Navigator.pop:
///    OLD: Navigator.pop(context)
///    NEW: context.back() or NavigationService.to(context).back()
///
/// 4. Replace Navigator.pop with result:
///    OLD: Navigator.pop(context, result)
///    NEW: context.backWithResult(result)
///
/// 5. Deep linking is now automatic!
///    Routes like '/donation-detail' will work from push notifications,
///    universal links, and direct URL access.
