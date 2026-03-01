# Riverpod State Management Migration Guide

## Phase 5: State Management Migration ✅

### Overview
Successfully migrated from **Provider** to **Riverpod** for state management. This provides:
- Better performance with selective rebuilds
- Compile-time safety
- Easier testing
- Better dev tools support
- Async state handling out of the box

---

## Dependencies Added

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

dev_dependencies:
  build_runner: ^2.4.11
  riverpod_generator: ^2.4.0
```

---

## Quick Reference

### Provider Types

| Old (Provider) | New (Riverpod) | Use Case |
|---------------|----------------|----------|
| `ChangeNotifierProvider` | `StateNotifierProvider` | Complex state with methods |
| `StreamProvider` | `StreamProvider` | Real-time data streams |
| `FutureProvider` | `FutureProvider` | Async operations |
| `Provider` | `Provider` | Computed/derived values |

---

## Migration Examples

### 1. Simple Provider

#### Before (Provider)
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Text(authService.userModel?.name ?? 'Guest');
  }
}
```

#### After (Riverpod)
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);
    return Text(userName ?? 'Guest');
  }
}
```

---

### 2. Async State with Loading

#### Before (Provider)
```dart
class UserProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: authService.getUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        return Text(snapshot.data?.name ?? 'Guest');
      },
    );
  }
}
```

#### After (Riverpod)
```dart
class UserProfile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userModelProvider);
    
    return userAsync.when(
      data: (user) => Text(user?.name ?? 'Guest'),
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
```

---

### 3. Selective Rebuilds

#### Before (Provider)
```dart
// Rebuilds when ANY user data changes
final user = Provider.of<AuthService>(context).userModel;
return Text(user?.name ?? '');
```

#### After (Riverpod)
```dart
// Only rebuilds when name changes
class UserNameWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(userNameProvider);
    return Text(name ?? 'Guest');
  }
}

// Or use select for even more granular control
final name = ref.watch(userModelProvider.select((u) => u.valueOrNull?.name));
```

---

## Available Providers

### Authentication Providers (`lib/providers/auth_provider.dart`)

| Provider | Type | Returns | Description |
|----------|------|---------|-------------|
| `authServiceProvider` | Provider | AuthService | Auth service instance |
| `firebaseUserProvider` | StreamProvider<User?> | Firebase user stream | Auth state |
| `isAuthenticatedProvider` | Provider<bool> | bool | Login status |
| `userModelProvider` | FutureProvider<UserModel?> | User data | Firestore user |
| `userLoadingProvider` | Provider<bool> | bool | Loading state |
| `userIdProvider` | Provider<String?> | String? | User ID |
| `userPhoneProvider` | Provider<String?> | String? | Phone number |
| `userKarmaProvider` | Provider<int> | int | Karma points |
| `userProfilePictureProvider` | Provider<String?> | String? | Profile image URL |
| `userNameProvider` | Provider<String?> | String? | User name |
| `userAreaProvider` | Provider<String?> | String? | User area |
| `userTrustScoreProvider` | Provider<int> | int | Trust score |
| `userBadgesProvider` | Provider<List<String>> | List<String> | User badges |
| `isUserBannedProvider` | Provider<bool> | bool | Ban status |
| `authNotifierProvider` | StateNotifierProvider | AsyncValue<void> | Auth operations |

---

## Usage Patterns

### Pattern 1: ConsumerWidget (Recommended)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class ProfileWidget extends ConsumerWidget {
  const ProfileWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);
    final userKarma = ref.watch(userKarmaProvider);

    return Column(
      children: [
        Text(userName ?? 'Guest'),
        Text('$userKarma Karma'),
      ],
    );
  }
}
```

---

### Pattern 2: Consumer (For partial rebuilds)

```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // This part doesn't rebuild when user changes
          Header(),
          
          // Only this part rebuilds
          Consumer(
            builder: (context, ref, child) {
              final userName = ref.watch(userNameProvider);
              return Text(userName ?? 'Guest');
            },
          ),
        ],
      ),
    );
  }
}
```

---

### Pattern 3: AsyncValue Handling

```dart
class UserProfile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userModelProvider);

    return userAsync.when(
      data: (user) => UserCard(user: user),
      loading: () => SkeletonLoader(), // Shimmer effect
      error: (err, stack) => ErrorWidget(error: err),
    );
  }
}
```

---

### Pattern 4: StateNotifier for Operations

```dart
class SettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return ElevatedButton(
      onPressed: authState.isLoading
        ? null
        : () => ref.read(authNotifierProvider.notifier).signOut(),
      child: authState.isLoading
        ? CircularProgressIndicator()
        : Text('Sign Out'),
    );
  }
}
```

---

## Best Practices

### ✅ DO

1. **Use ConsumerWidget** for widgets that need state
   ```dart
   class MyWidget extends ConsumerWidget { ... }
   ```

2. **Watch only what you need**
   ```dart
   // Good - only rebuilds when name changes
   final name = ref.watch(userNameProvider);
   
   // Less efficient - rebuilds on any user change
   final user = ref.watch(userModelProvider);
   ```

3. **Use AsyncValue for async data**
   ```dart
   final asyncData = ref.watch(myFutureProvider);
   return asyncData.when(
     data: (data) => Text(data),
     loading: () => CircularProgressIndicator(),
     error: (err, stack) => Text('Error: $err'),
   );
   ```

4. **Invalidate providers to refresh**
   ```dart
   ref.invalidate(userModelProvider);
   ```

5. **Use read for one-time operations**
   ```dart
   // In button callbacks
   onPressed: () {
     ref.read(authNotifierProvider.notifier).signOut();
   }
   ```

### ❌ DON'T

1. **Don't use context.watch in build**
   ```dart
   // ❌ Old Provider way
   final value = context.watch<MyProvider>();
   
   // ✅ Riverpod way
   final value = ref.watch(myProvider);
   ```

2. **Don't mutate state directly**
   ```dart
   // ❌ Wrong
   ref.read(myProvider).value = newValue;
   
   // ✅ Correct (use StateNotifier)
   ref.read(myProvider.notifier).updateValue(newValue);
   ```

3. **Don't forget WidgetRef parameter**
   ```dart
   // ❌ Missing WidgetRef
   class MyWidget extends ConsumerWidget {
     @override
     Widget build(BuildContext context) { ... } // Missing ref!
   }
   
   // ✅ Correct
   class MyWidget extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) { ... }
   }
   ```

---

## Testing with Riverpod

### Widget Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Profile widget shows user name', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ProfileWidget(),
        ),
      ),
    );
    
    expect(find.text('Guest'), findsOneWidget);
  });
}
```

### Overriding Providers

```dart
testWidgets('With mocked user', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userNameProvider.overrideWithValue('Test User'),
      ],
      child: MaterialApp(home: ProfileWidget()),
    ),
  );
  
  expect(find.text('Test User'), findsOneWidget);
});
```

---

## Files Modified

1. ✅ `pubspec.yaml` - Added Riverpod dependencies
2. ✅ `lib/main.dart` - Wrapped with `ProviderScope`
3. ✅ `lib/providers/auth_provider.dart` - Auth providers
4. ✅ `lib/providers/providers.dart` - Export file
5. ✅ `lib/providers/README.md` - Provider documentation

---

## Migration Status

| Feature | Old (Provider) | New (Riverpod) | Status |
|---------|---------------|----------------|--------|
| Main App | MultiProvider | ProviderScope | ✅ Migrated |
| Auth State | AuthService | auth_provider.dart | ✅ Migrated |
| User Data | ChangeNotifier | FutureProvider | ✅ Migrated |
| Loading States | Manual | AsyncValue | ✅ Migrated |
| Error Handling | Manual | AsyncValue | ✅ Migrated |

---

## Next Steps

1. **Migrate remaining screens** to ConsumerWidget
2. **Create providers** for:
   - Donations
   - Chat
   - Notifications
   - Settings
3. **Add code generation** with `build_runner`
4. **Write tests** using ProviderScope overrides

---

## Troubleshooting

### Issue: "WidgetRef not found"
**Solution:** Make sure your widget extends `ConsumerWidget` and includes `WidgetRef ref` in build method

### Issue: "Provider not found"
**Solution:** Ensure `ProviderScope` wraps your app in `main.dart`

### Issue: "State not updating"
**Solution:** Use `ref.watch()` not `ref.read()` in build methods

---

## Performance Tips

1. **Use `.select()` for granular updates**
   ```dart
   // Only rebuild when name changes
   final name = ref.watch(userProvider.select((u) => u?.name));
   ```

2. **Cache expensive computations**
   ```dart
   final sortedList = ref.watch(
     myListProvider.select((list) => _expensiveSort(list))
   );
   ```

3. **Avoid watching in callbacks**
   ```dart
   // ❌ Don't do this
   onPressed: () {
     final value = ref.watch(myProvider);
   }
   
   // ✅ Do this
   onPressed: () {
     final value = ref.read(myProvider);
   }
   ```

---

*Last Updated: Thu Feb 26, 2026*
*Phase 5: State Management Migration - COMPLETED*
