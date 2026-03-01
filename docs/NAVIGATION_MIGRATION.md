# Navigation Migration Guide

## Phase 4: GoRouter Implementation ✅

### Overview
We've successfully migrated from Material Navigator to **GoRouter** for declarative navigation. This provides:
- Deep linking support
- Type-safe routes
- Better maintainability
- Web/desktop compatibility

---

## Quick Reference

### Navigation Patterns

#### Before (Old Way)
```dart
// Navigate to new screen
Navigator.pushNamed(context, '/home');

// Navigate with data
Navigator.pushNamed(
  context,
  '/donation-detail',
  arguments: donation,
);

// Go back
Navigator.pop(context);

// Go back with result
Navigator.pop(context, result);
```

#### After (New Way)
```dart
// Method 1: Using NavigationService (Recommended)
NavigationService.to(context).goHome();
NavigationService.to(context).goDonationDetail(donation);
NavigationService.to(context).back();

// Method 2: Using BuildContext extension
context.goHome();
context.goDonationDetail(donation);
context.back();

// Method 3: Using GoRouter directly (advanced)
context.go('/home');
context.go('/donation-detail', extra: donation);
context.pop();
```

---

## Available Routes

| Route | Navigation Method | Parameters |
|-------|------------------|------------|
| `/` | `goSplash()` | None |
| `/home` | `goHome()` | None |
| `/post-food` | `goPostFood()` | None |
| `/post-appliances` | `goPostAppliances()` | None |
| `/post-blood` | `goPostBlood()` | None |
| `/post-stationery` | `goPostStationery()` | None |
| `/donation-detail` | `goDonationDetail(donation)` | `Map<String, dynamic>` |
| `/reserve-item` | `goReserveItem(donation)` | `Map<String, dynamic>` |

---

## Migration Steps

### Step 1: Update imports
Remove old navigation imports if any, keep:
```dart
import 'package:flutter/material.dart';
import 'services/navigation_service.dart'; // Optional
```

### Step 2: Replace navigation calls

#### Auth Flow
```dart
// OLD
Navigator.pushReplacementNamed(context, '/home');

// NEW
context.goHome(); // or NavigationService.to(context).goHome()
```

#### Donation Detail
```dart
// OLD
Navigator.pushNamed(
  context,
  '/donation-detail',
  arguments: donation,
);

// NEW
context.goDonationDetail(donation);
```

#### Posting Donations
```dart
// OLD
Navigator.pushNamed(context, '/post-food');

// NEW
context.goPostFood();
```

#### Going Back
```dart
// OLD
Navigator.pop(context);

// NEW
context.back(); // or NavigationService.to(context).back()

// With result
context.backWithResult(result);
```

---

## Important Notes

### 1. Extra Data (Arguments)
GoRouter uses `extra` instead of `arguments`:
```dart
// OLD
arguments: donation

// NEW
extra: donation
```

### 2. Path Parameters
For routes with parameters (when we add them):
```dart
// Example: /donation-detail/:id
context.go('/donation-detail/123');
// or
context.goNamed('donationDetail', pathParameters: {'id': '123'});
```

### 3. Query Parameters
```dart
context.go('/home?tab=donations');
// Access with: state.uri.queryParameters['tab']
```

---

## Error Handling

Unknown routes automatically show a 404 page. You can customize this in `app_router.dart`:

```dart
errorBuilder: (context, state) {
  return MyCustom404Page(path: state.uri.path);
},
```

---

## Deep Linking

### Android (AndroidManifest.xml)
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="givelocally.app" />
</intent-filter>
```

### iOS (Info.plist)
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>givelocally.app</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>https</string>
    </array>
  </dict>
</array>
```

---

## Testing Navigation

```dart
// Test helper
testWidgets('navigation test', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: AppRouter.router,
    ),
  );
  
  // Tap button that navigates
  await tester.tap(find.text('Go Home'));
  await tester.pumpAndSettle();
  
  // Verify navigation
  expect(find.text('Home Screen'), findsOneWidget);
});
```

---

## Files Modified

1. ✅ `pubspec.yaml` - Added `go_router` dependency
2. ✅ `lib/routes/app_router.dart` - Router configuration
3. ✅ `lib/services/navigation_service.dart` - Navigation helpers
4. ✅ `lib/main.dart` - Updated to use `MaterialApp.router`

---

## Migration Status

| Screen | Status | Migrated By |
|--------|--------|-------------|
| Splash Screen | ⏳ Pending | - |
| Home Screen | ⏳ Pending | - |
| Donation Detail | ⏳ Pending | - |
| Post Food | ⏳ Pending | - |
| Post Appliances | ⏳ Pending | - |
| Post Blood | ⏳ Pending | - |
| Post Stationery | ⏳ Pending | - |

**Recommendation:** Migrate screens gradually as you work on them. The NavigationService allows both old and new navigation to work during the transition.

---

## Troubleshooting

### Issue: "Target of URI doesn't exist"
**Solution:** Run `flutter pub get` to install go_router

### Issue: "The method 'go' isn't defined"
**Solution:** Import navigation_service.dart or use BuildContext extension

### Issue: Routes not working
**Solution:** Check route paths match exactly in `app_router.dart`

---

## Next Steps

1. Test the app with new navigation
2. Update screens gradually using this guide
3. Remove old navigation code when migration is complete
4. Add deep linking configuration for production

---

*Last Updated: Thu Feb 26, 2026*
*Phase 4: Navigation Migration - COMPLETED*
