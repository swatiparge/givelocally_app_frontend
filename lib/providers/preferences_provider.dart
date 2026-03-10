// lib/providers/preferences_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'Initialize in main.dart with ProviderScope overrides',
  );
});

/// Provider to check if user has seen Get Started section
final hasSeenGetStartedProvider = FutureProvider<bool>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('has_seen_get_started') ?? false;
});

/// Notifier to manage Get Started visibility
class GetStartedNotifier extends StateNotifier<AsyncValue<bool>> {
  final SharedPreferences _prefs;

  GetStartedNotifier(this._prefs) : super(const AsyncValue.loading());

  Future<void> load() async {
    try {
      final hasSeen = _prefs.getBool('has_seen_get_started') ?? false;
      state = AsyncValue.data(hasSeen);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> markAsSeen() async {
    try {
      await _prefs.setBool('has_seen_get_started', true);
      state = const AsyncValue.data(true);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> reset() async {
    try {
      await _prefs.setBool('has_seen_get_started', false);
      state = const AsyncValue.data(false);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

/// StateNotifier provider for Get Started visibility
final getStartedNotifierProvider =
    StateNotifierProvider<GetStartedNotifier, AsyncValue<bool>>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return GetStartedNotifier(prefs);
    });
