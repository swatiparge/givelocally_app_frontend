# Testing the Sample App

This guide walks you through setting up and running the Google Maps Plugin sample application on all platforms.

## Prerequisites

- Flutter SDK 3.0.0 or higher
- Google Maps API Key from [Google Cloud Console](https://console.cloud.google.com/)
- Platform-specific tools:
  - **Android:** Android Studio with SDK
  - **iOS:** Xcode 14+ with iOS Simulator or physical device
  - **Web:** Chrome or other modern browser

## Step 1: Get Your API Key

1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable these APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Maps JavaScript API (for web)
4. Go to **Credentials** → **Create Credentials** → **API Key**
5. Copy your API key for the next steps

## Step 2: Environment Setup

### Create Environment File

```bash
cd google_maps_plugin/sample_app
cp .env.example .env
```

The `.env` file stores configuration values. While the API keys for mobile platforms go in native config files, other settings can go here.

## Step 3: Platform-Specific Configuration

### Android Setup

1. Open `android/app/src/main/AndroidManifest.xml`
2. Find the placeholder and replace with your API key:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE" />
```

3. Location permissions are already added:
   ```xml
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   ```

4. Install dependencies:
   ```bash
   flutter pub get
   ```

5. Run:
   ```bash
   flutter run
   ```

### iOS Setup

1. Open `ios/Runner/AppDelegate.swift`
2. Replace the placeholder:

```swift
GMSServices.provideAPIKey("YOUR_ACTUAL_API_KEY_HERE")
```

3. Install CocoaPods dependencies:
   ```bash
   cd ios
   pod install
   cd ..
   ```

4. Location permissions are already configured in `Info.plist`

5. Run on simulator:
   ```bash
   flutter run
   ```

6. Run on physical device (requires Apple Developer account):
   ```bash
   flutter run -d <device_id>
   ```

### Web Setup

**Important:** Unlike mobile platforms, web requires the API key in the HTML file.

1. Open `web/index.html`
2. Find this line and replace with your API key:

```html
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY_HERE"></script>
```

3. Run:
   ```bash
   flutter run -d chrome
   ```

## Step 4: Test the Features

Once the app runs, you will see two demo options:

### Unified Map View
- Shows an interactive map centered on Hyderabad, India
- Displays mock donation items as colored markers
- Tap markers to view item details
- Use the filter button to show specific categories
- Drag the map to trigger smart refresh (debounced)

### Location Picker
- Opens a map with a draggable pin
- Tap "Use my location" to center on your position
- Drag the map to move the pin
- Tap confirm to select the location
- View coordinates and address

## Troubleshooting

### Blank Map (Gray Screen)

**Android:**
- Verify API key in `AndroidManifest.xml`
- Check that Maps SDK for Android is enabled in Google Cloud Console
- Ensure billing is enabled

**iOS:**
- Verify API key in `AppDelegate.swift`
- Check that Maps SDK for iOS is enabled
- Clean build: `cd ios && rm -rf Podfile.lock Pods/ && pod install`

**Web:**
- Verify API key in `web/index.html` (not in `.env`)
- Check browser console for JavaScript errors
- Ensure Maps JavaScript API is enabled

### Location Permission Denied

The app requests permissions automatically. If denied:
- **iOS Simulator:** Features → Location → Select a custom location
- **Physical Device:** Check Settings → Privacy → Location Services

### Build Errors

Clean and rebuild:
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..  # For iOS
flutter run
```

## Test Checklist

- [ ] Map loads and shows markers
- [ ] Tapping markers opens detail view
- [ ] Category filter works
- [ ] Map dragging triggers refresh
- [ ] Location picker opens
- [ ] Draggable pin works
- [ ] "Use my location" centers map
- [ ] Selected location displays coordinates

## Next Steps

After testing the sample app, integrate the plugin into your project following the [Integration Guide](INTEGRATION.md).
