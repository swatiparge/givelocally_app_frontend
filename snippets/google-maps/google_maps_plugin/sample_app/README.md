# Google Maps Plugin Sample App

A complete sample Flutter application demonstrating the `google_maps_plugin` package.

## Features Demonstrated

### 1. UnifiedMapView Demo
- Interactive map with auto-location
- Category-based markers (Food, Appliances, Blood, Stationery)
- Smart refresh with debouncing
- Filter by category
- Tap markers to view details

### 2. LocationPicker Demo
- Draggable pin location selector
- "Use my location" button
- Selected location display
- Address placeholder (connect to backend for full functionality)

## API Key Configuration

### IMPORTANT: Platform-Specific Setup

Each platform requires API keys to be configured differently:

#### 🔑 **Option 1: Using .env file (Recommended for Development)**

1. Copy the example file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and add your API key:
   ```
   GOOGLE_MAPS_API_KEY=your_actual_api_key_here
   ```

3. **For Web:** The API key is loaded via Dart code using `flutter_dotenv`

4. **For Android/iOS:** See platform-specific instructions below

#### 📱 **Android Setup**

Android requires the API key in `AndroidManifest.xml`:

1. Open `android/app/src/main/AndroidManifest.xml`
2. Add inside the `<application>` tag:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_API_KEY_HERE" />
   ```

3. Also add location permissions:
   ```xml
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   ```

#### 🍎 **iOS Setup**

iOS requires the API key in `AppDelegate.swift`:

1. Open `ios/Runner/AppDelegate.swift`
2. Add import at the top:
   ```swift
   import GoogleMaps
   ```
3. Add in `application(_:didFinishLaunchingWithOptions:)`:
   ```swift
   GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
   ```

4. Add location permission to `ios/Runner/Info.plist`:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>This app needs location to show nearby items</string>
   ```

#### 🌐 **Web Setup**

**⚠️ IMPORTANT:** For Flutter Web, the Google Maps JavaScript API **MUST** be loaded in `web/index.html` before the Flutter app starts. The `.env` file or `--dart-define` approach does NOT work for web because the maps library needs to be loaded before the widget tree is built.

**Steps:**

1. Open `web/index.html`
2. Find this line near the bottom of `<head>`:
   ```html
   <script src="https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY_HERE"></script>
   ```
3. Replace `YOUR_API_KEY_HERE` with your actual API key

**Example:**
```html
<script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyYourActualKeyHere"></script>
```

**Note:** Unlike Android/iOS, you cannot use `.env` or `--dart-define` for the web API key. It must be in the HTML file.
}
```

### Getting Your API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the required APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Maps JavaScript API (for web)
4. Go to "Credentials" → "Create Credentials" → "API Key"
5. **Optional but recommended:** Restrict the API key
   - Set HTTP referrers (for web)
   - Set package name/sha-1 (for Android)
   - Set bundle identifier (for iOS)

## Running the App

### Prerequisites

1. Flutter SDK (>=3.0.0)
2. Android Studio or Xcode (for mobile emulators)
3. Chrome (for web)
4. Google Maps API Key (see above)

### Install Dependencies

```bash
flutter pub get
```

### Run on Android

```bash
# Make sure AndroidManifest.xml has your API key
flutter run
```

### Run on iOS

```bash
# Make sure AppDelegate.swift has your API key
cd ios && pod install && cd ..
flutter run
```

### Run on Web

```bash
# Using .env file
flutter run -d chrome

# Or using dart-define
flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY=your_api_key_here
```

## Project Structure

```
lib/
├── main.dart                          # Entry point with home screen
├── models/
│   └── donation.dart                  # Sample models implementing MapMarkerItem
├── data/
│   └── mock_donations.dart           # Mock data for demo
└── screens/
    ├── map_demo_screen.dart          # UnifiedMapView demo
    ├── location_picker_demo_screen.dart  # LocationPicker demo
    └── donation_detail_screen.dart   # Detail view for tapped items
```

## How It Works

### Using the Plugin

The sample app demonstrates two main use cases:

#### 1. Displaying Items on Map (UnifiedMapView)

```dart
UnifiedMapView(
  onFetchItems: (LatLng center, double radius) async {
    // Fetch items based on map center and radius
    // In real app: call your backend API
    final items = await fetchFromBackend(center, radius);
    return items;
  },
  categoryIcons: {
    'food': foodIcon,
    'appliances': appliancesIcon,
    // ... more icons
  },
  onItemTap: (item) {
    // Handle marker tap
    navigateToDetail(item);
  },
)
```

#### 2. Picking a Location (LocationPicker)

```dart
LocationPicker(
  onLocationSelected: (LocationResult result) {
    print('Selected: ${result.location}');
    print('Address: ${result.address}');
  },
)
```

### Mock Data

The app uses mock data located in `lib/data/mock_donations.dart`. These are sample donations around Hyderabad, India coordinates. In a real application, you would:

1. Connect to your backend API
2. Use the Cloud Functions from the plugin
3. Implement proper authentication

### Backend Integration

To use with real backend:

1. Deploy the Firebase Functions from `../firebase_functions/`
2. Update the `_fetchItems` method in `map_demo_screen.dart`:

```dart
Future<List<MapMarkerItem>> _fetchItems(LatLng center, double radius) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('nearbySearch')
      .call({
        'latitude': center.latitude,
        'longitude': center.longitude,
        'radiusKm': radius,
        'collection': 'donations',
      });
  
  return (result.data['results'] as List)
      .map((item) => Donation.fromJson(item))
      .toList();
}
```

## Customization

### Adding Your Own Data Model

1. Create a model class implementing `MapMarkerItem`:

```dart
class Store implements MapMarkerItem {
  @override
  final String id;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final String category;
  @override
  final String title;
  @override
  final String? snippet;
  
  // Your custom fields...
  
  Store({...});
}
```

2. Use it with UnifiedMapView:

```dart
UnifiedMapView(
  onFetchItems: (center, radius) async {
    final stores = await fetchStores(center, radius);
    return stores; // List<Store> works automatically!
  },
  // ... other properties
)
```

### Custom Map Styles

You can provide a JSON map style string:

```dart
UnifiedMapView(
  mapStyle: darkModeStyleJson, // Your custom style
  // ...
)
```

Get styles from: https://mapstyle.withgoogle.com/

## Troubleshooting

### Map shows blank/gray screen or "Cannot read properties of undefined (reading 'maps')" error

**Web:**
- ⚠️ **CRITICAL:** Web requires the API key in `web/index.html`, NOT in `.env` file
- Open `web/index.html` and replace `YOUR_API_KEY_HERE` in this line:
  ```html
  <script src="https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY_HERE"></script>
  ```
- Make sure "Maps JavaScript API" is enabled in Google Cloud Console

**Android:**
- Verify API key is in `android/app/src/main/AndroidManifest.xml`
- Check that "Maps SDK for Android" is enabled in Google Cloud Console

**iOS:**
- Verify API key is in `ios/Runner/AppDelegate.swift`
- Check that "Maps SDK for iOS" is enabled in Google Cloud Console

**All platforms:**
- Ensure billing is enabled on your Google Cloud project
- Verify the API key is correct and not restricted (or properly restricted for your domain/package)

### Location permission denied
- The plugin handles permission requests automatically
- Make sure permissions are in `AndroidManifest.xml` (Android)
- Make sure `NSLocationWhenInUseUsageDescription` is in `Info.plist` (iOS)

### Markers not showing
- Verify `categoryIcons` map contains icons for all your categories
- Check that items have valid latitude/longitude values
- Look at debug console for error messages

### .env file not loading
- Make sure `.env` exists (copy from `.env.example`)
- Ensure `.env` is listed in `pubspec.yaml` assets
- Run `flutter clean` and `flutter pub get`
- Restart the app completely (hot reload may not pick up asset changes)

## Next Steps

1. Integrate with your backend API
2. Add custom marker icons
3. Implement clustering for large datasets
4. Add more interactive features
5. Deploy Cloud Functions for cost optimization

## License

MIT
