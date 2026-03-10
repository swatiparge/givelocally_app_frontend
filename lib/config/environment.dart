class Environment {
  static const bool useEmulator = false;

  // Region changed to asia-southeast1 to match ApiService and working backend
  static const String functionsRegion = 'asia-southeast1';

  static const String authEmulatorHost = '127.0.0.1';
  static const int authEmulatorPort = 9099;

  static const String firestoreEmulatorHost = '127.0.0.1';
  static const int firestoreEmulatorPort = 8080;

  static const String functionsEmulatorHost = '127.0.0.1';
  static const int functionsEmulatorPort = 5001;
}
