# Google Maps Plugin Design Document

*Date: 2026-02-06*  
*Status: ✅ Implementation Complete*

## Executive Summary

A reusable, plug-and-play Google Maps module for Flutter applications. The plugin is completely decoupled from business logic, working with any data type that implements the `MapMarkerItem` interface.

## Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENT LAYER (Flutter)                   │
├─────────────────────────────────────────────────────────────┤
│  google_maps_plugin                                         │
│  ├─ UnifiedMapView       (Auto-locating, smart refresh)     │
│  ├─ LocationPicker       (Draggable pin selector)          │
│  └─ MapMarkerItem        (Generic data contract)           │
└─────────────────────────────────────────────────────────────┘
                              ↓ HTTPS (Firebase Functions)
┌─────────────────────────────────────────────────────────────┐
│                   APPLICATION LAYER (Firebase)              │
├─────────────────────────────────────────────────────────────┤
│  Cloud Functions (Node.js 18)                               │
│  ├─ nearbySearch         (Generic radius search)            │
│  └─ geocodeAddress       (Cached geocoding)                │
└─────────────────────────────────────────────────────────────┘
                              ↓ Firestore
┌─────────────────────────────────────────────────────────────┐
│                     DATA LAYER                              │
├─────────────────────────────────────────────────────────────┤
│  Firestore                                                  │
│  ├─ donations        (your app's data)                      │
│  ├─ geo_cache        (cached geocoding results)            │
│  └─ users            (location preferences)                │
└─────────────────────────────────────────────────────────────┘
```

## Frontend Components

### MapMarkerItem Interface

Abstract contract ensuring the map remains independent of business logic.

```dart
abstract class MapMarkerItem {
  String get id;
  double get latitude;
  double get longitude;
  String get category;
  String get title;
  String? get snippet;
}
```

### UnifiedMapView

The main map widget for browsing items.

**Key Features:**
- **Auto-Center:** Uses `geolocator` to find user on load
- **Smart Refresh:** Debounced fetching (500ms) when camera stops
- **Custom Icons:** Category-based marker selection
- **Performance:** Efficient marker rendering with native Google Maps SDK

**API:**
```dart
UnifiedMapView(
  onFetchItems: (LatLng center, double radius) async { ... },
  categoryIcons: {'food': foodIcon, 'blood': bloodIcon},
  onItemTap: (item) { ... },
  mapStyle: customJsonStyle,
  initialPosition: initialLatLng,
)
```

### LocationPicker

Widget for selecting locations with a draggable pin.

**Key Features:**
- Fixed center pin while map moves underneath
- "Use my location" button
- Address preview with loading state
- Coordinate display

**API:**
```dart
LocationPicker(
  onLocationSelected: (LocationResult result) { ... },
  confirmButtonText: 'Set Pickup Location',
)
```

## Backend Functions

### nearbySearch

Generic radius search using bounding box + Haversine filtering.

**Endpoint:** `httpsCallable('nearbySearch')`  
**Cache:** None (client provides)  
**Cost:** 1 read per item queried

**Logic:**
1. Calculate bounding box from center + radius
2. Query Firestore with GeoPoint range
3. Filter exact distance with Haversine formula
4. Sort by distance, return limited results

### geocodeAddress

Cached geocoding wrapper around Google Maps API.

**Endpoint:** `httpsCallable('geocodeAddress')`  
**Cache:** `geo_cache` collection  
**Cost:** 0 (if cached) or 1 Google API call

**Logic:**
1. Generate cache key from input (address or rounded lat/lng)
2. Check Firestore `geo_cache` collection
3. **Hit:** Return cached data
4. **Miss:** Call Google Geocoding API, cache result, return data

## Cost Optimization Strategies

1. **Geocoding Cache:** Saves ~90% of geocoding costs for common addresses
2. **Bounding Box:** Reduces Firestore reads by 50-70% vs pure Haversine
3. **Debounced Fetching:** Prevents API spam during rapid map movements
4. **No Reverse Geocoding:** Only geocode on explicit user confirmation

## Integration Guide

### Step 1: Implement MapMarkerItem

```dart
class Donation implements MapMarkerItem {
  @override final String id;
  @override final double latitude;
  @override final double longitude;
  @override final String category;
  @override final String title;
  @override final String? snippet;
  
  // Your fields
  final String description;
  final String donorId;
  
  Donation({...});
  
  factory Donation.fromJson(Map<String, dynamic> json) => ...
}
```

### Step 2: Use in Map View

```dart
UnifiedMapView(
  onFetchItems: (center, radius) async {
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
  },
  categoryIcons: await _loadIcons(),
  onItemTap: (item) => _navigateToDetail(item as Donation),
)
```

### Step 3: Deploy Backend

```bash
cd firebase_functions
npm install
firebase deploy --only functions
firebase functions:secrets:set GOOGLE_MAPS_API_KEY
```

## File Structure

```
google_maps_plugin/
├── README.md
├── flutter_package/
│   ├── lib/
│   │   ├── google_maps_plugin.dart
│   │   ├── models/
│   │   │   └── map_marker_item.dart
│   │   ├── widgets/
│   │   │   ├── unified_map_view.dart
│   │   │   └── location_picker.dart
│   │   └── services/
│   │       └── geolocation_service.dart
│   ├── test/
│   │   └── flutter_package_test.dart
│   └── pubspec.yaml
└── firebase_functions/
    ├── package.json
    ├── tsconfig.json
    └── src/
        ├── index.ts
        ├── config.ts
        ├── geocodeAddress.ts
        └── nearbySearch.ts
```

## Testing

Run Flutter tests:
```bash
cd flutter_package
flutter test
```

## Next Steps

1. Add to your main app:
   - Add dependency to `pubspec.yaml`
   - Implement `MapMarkerItem` on your data model
   - Configure Cloud Functions
   - Add Google Maps API key to Firebase secrets

2. Integration examples:
   - Replace `lib/screens/home/map_view.dart` with `UnifiedMapView`
   - Replace `lib/screens/donation/location_picker_screen.dart` with `LocationPicker`

---

*End of Design Document*
