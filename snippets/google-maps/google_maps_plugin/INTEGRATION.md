# Integration Guide

Add the Google Maps Plugin to your Flutter project and start displaying location-based data.

## Overview

This plugin provides:
- **UnifiedMapView:** Display items on an interactive map
- **LocationPicker:** Let users select locations
- **Generic Interface:** Works with any data type
- **Firebase Backend:** Cloud Functions for geocoding and search

## Step 1: Add the Plugin

### Option A: Local Path (Recommended for Development)

Copy the plugin to your project:

```bash
# From your project root
mkdir -p packages
cp -r /path/to/google_maps_plugin/flutter_package packages/google_maps_plugin
```

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  google_maps_plugin:
    path: ./packages/google_maps_plugin
```

### Option B: Git Repository

```yaml
dependencies:
  google_maps_plugin:
    git:
      url: https://github.com/yourusername/google_maps_plugin.git
      path: flutter_package
```

## Step 2: Install Dependencies

```bash
flutter pub get
```

## Step 3: Configure API Keys

### Android

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<application ...>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_API_KEY" />
</application>

<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS

Edit `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

Edit `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs your location</string>
```

### Web

Edit `web/index.html`:

```html
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY"></script>
```

## Step 4: Implement Your Data Model

Your model must implement `MapMarkerItem`:

```dart
import 'package:google_maps_plugin/google_maps_plugin.dart';

class Donation implements MapMarkerItem {
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
  
  // Your fields
  final String description;
  final String donorId;
  final DateTime createdAt;
  
  Donation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.title,
    this.snippet,
    required this.description,
    required this.donorId,
    required this.createdAt,
  });
  
  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      id: json['id'],
      latitude: json['location']['latitude'],
      longitude: json['location']['longitude'],
      category: json['category'],
      title: json['title'],
      snippet: json['description']?.toString().substring(0, 50),
      description: json['description'],
      donorId: json['donorId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
```

## Step 5: Use UnifiedMapView

```dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_plugin/google_maps_plugin.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Map<String, BitmapDescriptor> categoryIcons = {};
  bool iconsLoaded = false;
  
  @override
  void initState() {
    super.initState();
    _loadIcons();
  }
  
  Future<void> _loadIcons() async {
    // Load custom icons or use default markers
    categoryIcons = {
      'food': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      'appliances': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      'blood': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      'stationery': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    };
    setState(() => iconsLoaded = true);
  }
  
  Future<List<MapMarkerItem>> _fetchItems(LatLng center, double radius) async {
    // Option 1: Fetch from your backend
    final response = await http.get(Uri.parse(
      'https://your-api.com/items?lat=${center.latitude}&lng=${center.longitude}&radius=$radius'
    ));
    final data = jsonDecode(response.body);
    return (data['items'] as List).map((i) => Donation.fromJson(i)).toList();
    
    // Option 2: Use Firebase Cloud Functions
    // final result = await FirebaseFunctions.instance
    //     .httpsCallable('nearbySearch')
    //     .call({
    //       'latitude': center.latitude,
    //       'longitude': center.longitude,
    //       'radiusKm': radius,
    //       'collection': 'donations',
    //     });
    // return (result.data['results'] as List)
    //     .map((i) => Donation.fromJson(i))
    //     .toList();
  }
  
  void _onItemTap(MapMarkerItem item) {
    final donation = item as Donation;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DonationDetailScreen(donation: donation),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nearby Donations')),
      body: iconsLoaded
        ? UnifiedMapView(
            onFetchItems: _fetchItems,
            categoryIcons: categoryIcons,
            onItemTap: _onItemTap,
            initialPosition: LatLng(17.3850, 78.4867), // Default center
          )
        : Center(child: CircularProgressIndicator()),
    );
  }
}
```

## Step 6: Use LocationPicker

```dart
void _pickLocation() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LocationPicker(
        onLocationSelected: (LocationResult result) {
          print('Selected: ${result.location}');
          print('Address: ${result.address}');
          
          // Save to your state/database
          setState(() {
            selectedLocation = result.location;
            selectedAddress = result.address;
          });
          
          Navigator.pop(context);
        },
        confirmButtonText: 'Set Pickup Location',
      ),
    ),
  );
}
```

## Step 7: Deploy Backend (Optional)

If you want to use the Firebase Cloud Functions:

1. Copy the functions to your Firebase project:
   ```bash
   cp -r /path/to/google_maps_plugin/firebase_functions/* your-project/functions/
   ```

2. Install dependencies:
   ```bash
   cd your-project/functions
   npm install
   ```

3. Add your Google Maps API key:
   ```bash
   firebase functions:secrets:set GOOGLE_MAPS_API_KEY
   ```

4. Deploy:
   ```bash
   firebase deploy --only functions
   ```

## Configuration Options

### Custom Map Style

```dart
UnifiedMapView(
  mapStyle: '''
    [
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {"color": "#e9e9e9"}
        ]
      }
    ]
  ''',
  // ... other props
)
```

Get styles from: https://mapstyle.withgoogle.com/

### Debounce Duration

The default debounce is 500ms. You can modify this in the widget source if needed.

### Maximum Items

The plugin limits markers to optimize performance. The default is 20 items.

## Troubleshooting

### Map Not Showing

- Verify API key is correct for the platform
- Check that the Maps SDK is enabled in Google Cloud Console
- Ensure billing is enabled on your Google Cloud project

### Markers Not Appearing

- Verify `categoryIcons` contains icons for all categories in your data
- Check that latitude/longitude values are valid
- Look for errors in the console

### Permission Denied

- Check that location permissions are in `AndroidManifest.xml` (Android)
- Check that `Info.plist` has location descriptions (iOS)
- Ensure the user grants permission when prompted

## Example Projects

See the [sample app](sample_app/) for a complete working example with mock data.

## API Reference

### MapMarkerItem

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique identifier |
| `latitude` | `double` | Item latitude |
| `longitude` | `double` | Item longitude |
| `category` | `String` | Category for icon selection |
| `title` | `String` | Info window title |
| `snippet` | `String?` | Optional subtitle |

### UnifiedMapView

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `onFetchItems` | `Function(LatLng, double)` | Yes | Fetch items based on center and radius |
| `categoryIcons` | `Map<String, BitmapDescriptor>` | Yes | Icons for each category |
| `onItemTap` | `Function(MapMarkerItem)` | Yes | Callback when marker tapped |
| `mapStyle` | `String?` | No | Custom map style JSON |
| `initialPosition` | `LatLng?` | No | Initial map center |

### LocationPicker

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `onLocationSelected` | `Function(LocationResult)` | Yes | Callback with selected location |
| `initialPosition` | `LatLng?` | No | Initial map center |
| `confirmButtonText` | `String` | No | Button text (default: "Confirm Location") |

## License

MIT
