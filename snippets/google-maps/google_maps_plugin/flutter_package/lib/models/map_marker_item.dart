/// Abstract contract that any object you want to show on the map must implement.
/// This ensures the map remains completely decoupled from business logic.
abstract class MapMarkerItem {
  String get id;
  double get latitude;
  double get longitude;
  String get category; // e.g., 'food', 'blood' -> maps to an icon
  String get title; // Used for the info window
  String? get snippet; // Optional description
}
