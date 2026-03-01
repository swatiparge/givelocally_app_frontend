// lib/providers/auth_provider.dart
// Riverpod State Management for Authentication
// Phase 5: State Management Migration

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

/// Provider for AuthService instance
///
/// This provider gives access to the AuthService singleton
/// during the migration period from Provider to Riverpod
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService();
});

/// Provider for current Firebase User
///
/// Returns null if not logged in, User if authenticated
/// Automatically updates when auth state changes
final firebaseUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.user;
});

/// Provider for authentication state
///
/// Use this to check if user is logged in
final isAuthenticatedProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.when(
    data: (user) => user != null,
    loading: () => false,
    error: (err, stack) => false,
  );
});

/// Provider for current user model from Firestore
///
/// Returns null if not logged in or user data not loaded
final userModelProvider = FutureProvider<UserModel?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  // Access the userModel from AuthService
  // This will be null initially, then load from Firestore
  return authService.userModel;
});

/// Provider for user loading state
final userLoadingProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(userModelProvider);
  return userAsync.isLoading;
});

/// Provider for user ID
///
/// Returns null if not authenticated
final userIdProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.when(
    data: (user) => user?.uid,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for user phone number
final userPhoneProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.when(
    data: (user) => user?.phoneNumber,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for user karma points
///
/// Returns 0 if user not loaded
final userKarmaProvider = Provider<int>((ref) {
  final userModelAsync = ref.watch(userModelProvider);
  return userModelAsync.when(
    data: (user) => user?.karmaPoints ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for user profile picture
final userProfilePictureProvider = Provider<String?>((ref) {
  final userModelAsync = ref.watch(userModelProvider);
  return userModelAsync.when(
    data: (user) => user?.profilePicture,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for user name
final userNameProvider = Provider<String?>((ref) {
  final userModelAsync = ref.watch(userModelProvider);
  return userModelAsync.when(
    data: (user) => user?.name,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for user area/location
final userAreaProvider = Provider<String?>((ref) {
  final userModelAsync = ref.watch(userModelProvider);
  return userModelAsync.when(
    data: (user) => user?.area,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for user trust score
final userTrustScoreProvider = Provider<int>((ref) {
  final userModelAsync = ref.watch(userModelProvider);
  return userModelAsync.when(
    data: (user) => user?.trustScore ?? 50,
    loading: () => 50,
    error: (_, __) => 50,
  );
});

/// Provider for user badges
final userBadgesProvider = Provider<List<String>>((ref) {
  final userModelAsync = ref.watch(userModelProvider);
  return userModelAsync.when(
    data: (user) => user?.badges ?? [],
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider to check if user is banned
final isUserBannedProvider = Provider<bool>((ref) {
  final userModelAsync = ref.watch(userModelProvider);
  return userModelAsync.when(
    data: (user) => user?.isBanned ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// StateNotifier for Auth Operations
///
/// Use this for operations that need loading states and error handling
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authService = _ref.read(authServiceProvider);
      await authService.signOut();
    });
  }

  Future<void> refreshUserData() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Force refresh of user data
      _ref.invalidate(userModelProvider);
    });
  }
}

/// Provider for AuthNotifier
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
      return AuthNotifier(ref);
    });

/// Migration Notes:
///
/// OLD (Provider):
/// ```dart
/// final authService = Provider.of<AuthService>(context);
/// final user = authService.userModel;
/// ```
///
/// NEW (Riverpod):
/// ```dart
/// final userAsync = ref.watch(userModelProvider);
/// userAsync.when(
///   data: (user) => Text(user?.name ?? 'Guest'),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Error: $err'),
/// );
/// ```
///
/// Or use ConsumerWidget:
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final userName = ref.watch(userNameProvider);
///     return Text(userName ?? 'Guest');
///   }
/// }
/// ```
