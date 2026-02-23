# Google Maps Plugin

A reusable, plug-and-play Google Maps module for Flutter with Firebase Cloud Functions backend.

## Overview

This plugin provides a generic, decoupled solution for displaying location-based items on a map. It's designed to be completely independent of your business logic, working with any data type that implements the `MapMarkerItem` interface.

## Features

### Frontend (Flutter)
- **UnifiedMapView**: Auto-locating map with smart refresh and debounced fetching
- **LocationPicker**: Draggable pin location selector with address lookup
- **Generic Interface**: Works with any data type (Donations, Stores, Events, etc.)
- **Custom Icons**: Category-based marker icons
- **Geolocation**: Automatic permission handling and current location detection

### Backend (Firebase Cloud Functions)
- **Cached Geocoding**: Reduces Google Maps API costs by caching address lookups
- **Nearby Search**: Generic radius search with bounding box optimization
- **Security**: API keys hidden on backend, not exposed in client

## Installation

### 1. Frontend Package

Add to your `pubspec.yaml`:

```yaml
dependencies:
  google_maps_plugin:
    path: ./google_maps_plugin/flutter_package
```

### 2. Backend Functions

Copy the `firebase_functions` folder to your Firebase project:

```bash
cp -r google_maps_plugin/firebase_functions/* your-firebase-project/functions/
```

Deploy the functions:

```bash
firebase deploy --only functions
```

### 3. Configure API Key

Add your Google Maps API key to Firebase Functions environment:

```bash
firebase functions:secrets:set GOOGLE_MAPS_API_KEY
```

## Usage

### Implement the Interface

Your data model must implement `MapMarkerItem`:

```dart
class Donation implements MapMarkerItem {
  @override
  final String id;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final String category; // 'food', 'blood', etc.
  @override
  final String title;
  @override
  final String? snippet;
  
  // Your other fields...
  final String description;
  final String donorId;
  
  Donation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.title,
    this.snippet,
    required this.description,
    required this.donorId,
  });
}
```

### Use UnifiedMapView

```dart
UnifiedMapView(
  onFetchItems: (LatLng center, double radius) async {
    // Call your Cloud Function
    final result = await FirebaseFunctions.instance
        .httpsCallable('nearbySearch')
        .call({
          'latitude': center.latitude,
          'longitude': center.longitude,
          'radiusKm': radius,
          'collection': 'donations',
          'category': selectedCategory,
        });
    
    // Convert response to List<Donation>
    final items = (result.data['results'] as List)
        .map((item) => Donation.fromJson(item))
        .toList();
    
    return items;
  },
  categoryIcons: {
    'food': await BitmapDescriptor.asset(
      ImageConfiguration(),
      'assets/icons/food.png',
    ),
    'blood': await BitmapDescriptor.asset(
      ImageConfiguration(),
      'assets/icons/blood.png',
    ),
  },
  onItemTap: (item) {
    // Navigate to detail screen
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DonationDetailScreen(item: item as Donation),
    ));
  },
)
```

### Use LocationPicker

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => LocationPicker(
    onLocationSelected: (LocationResult result) {
      print('Selected: ${result.location}');
      print('Address: ${result.address}');
      Navigator.pop(context);
    },
  ),
));
```

## API Reference

### MapMarkerItem

Abstract contract for items to display on the map:

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique identifier |
| `latitude` | `double` | Item latitude |
| `longitude` | `double` | Item longitude |
| `category` | `String` | Category for icon selection |
| `title` | `String` | Info window title |
| `snippet` | `String?` | Optional info window subtitle |

### UnifiedMapView

Main map widget with auto-location and smart refresh.

| Property | Type | Description |
|----------|------|-------------|
| `onFetchItems` | `Future<List<MapMarkerItem>> Function(LatLng, double)` | Callback to fetch items based on map center and radius |
| `categoryIcons` | `Map<String, BitmapDescriptor>` | Mapping of category names to marker icons |
| `onItemTap` | `void Function(MapMarkerItem)` | Callback when marker is tapped |
| `mapStyle` | `String?` | Optional JSON map style |
| `initialPosition` | `LatLng?` | Initial map center (auto-detected if null) |

### LocationPicker

Widget for selecting a location with a draggable pin.

| Property | Type | Description |
|----------|------|-------------|
| `onLocationSelected` | `ValueChanged<LocationResult>` | Callback with selected location |
| `initialPosition` | `LatLng?` | Initial map center |
| `confirmButtonText` | `String` | Text for confirm button |

### Cloud Functions

#### `nearbySearch`

Search for items within a radius.

**Request:**
```json
{
  "latitude": 17.385,
  "longitude": 78.486,
  "radiusKm": 5.0,
  "collection": "donations",
  "category": "food",
  "limit": 20
}
```

**Response:**
```json
{
  "results": [...],
  "count": 10
}
```

#### `geocodeAddress`

Convert address to coordinates (or reverse) with caching.

**Request:**
```json
{
  "address": "Hyderabad, India"
}
```
or
```json
{
  "lat": 17.385,
  "lng": 78.486
}
```

**Response:**
```json
{
  "source": "cache" | "google",
  "formatted_address": "Hyderabad, Telangana, India",
  "lat": 17.385,
  "lng": 78.486,
  "place_id": "ChIJx9Lr6tqZyzs..."
}
```

## Cost Optimization

This plugin implements several strategies to minimize Google Maps API costs:

1. **Geocoding Cache**: Address lookups are cached in Firestore indefinitely
2. **Bounding Box**: Queries use bounding box before Haversine distance filtering
3. **Debounced Fetching**: API calls only triggered 500ms after camera stops moving
4. **No Reverse Geocoding on Launch**: Only geocode when user confirms a location

## Directory Structure

```
google_maps_plugin/
├── flutter_package/          # Flutter plugin
│   ├── lib/
│   │   ├── models/
│   │   │   └── map_marker_item.dart
│   │   ├── widgets/
│   │   │   ├── unified_map_view.dart
│   │   │   └── location_picker.dart
│   │   ├── services/
│   │   │   └── geolocation_service.dart
│   │   └── google_maps_plugin.dart
│   ├── test/
│   └── pubspec.yaml
│
└── firebase_functions/       # Backend module
    └── src/
        ├── config.ts
        ├── geocodeAddress.ts
        ├── nearbySearch.ts
        └── index.ts
```

## License

MIT
