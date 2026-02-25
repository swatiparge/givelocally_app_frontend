import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class _PendingRequest {
  final Completer<List<dynamic>> completer;
  final double lat;
  final double lng;
  final String? category;
  final double radiusKm;
  final String? idToken;

  _PendingRequest({
    required this.completer,
    required this.lat,
    required this.lng,
    required this.category,
    required this.radiusKm,
    required this.idToken,
  });
}

class ApiService {
  // Singleton Pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _nearbyDonationsUrl =
      "https://getnearbydonations-u6nq5a5ajq-as.a.run.app";
  final String _receivedItemsUrl =
      "https://getreceiveditems-u6nq5a5ajq-as.a.run.app";

  // Cache and Request Deduplication
  final Map<String, DateTime> _lastRequestTime = {};
  final Map<String, List<dynamic>> _dataCache = {};
  final Map<String, Future<List<dynamic>>> _inflightRequests = {};

  // Debouncing - single timer for all requests
  Timer? _debounceTimer;
  final Map<String, _PendingRequest> _pendingRequests = {};

  static const Duration _debounceDelay = Duration(milliseconds: 800);
  static const int _cachePrecision = 2; // ~1.1km precision
  static const int _cacheTtlMinutes = 10;

  Future<List<dynamic>> fetchNearbyDonations({
    required double lat,
    required double lng,
    String? category,
    double radiusKm = 10,
  }) async {
    // Coarser precision (~1.1km) to reduce cache misses from small movements
    final cacheKey =
        "nearby_${category ?? 'all'}_${lat.toStringAsFixed(_cachePrecision)}_${lng.toStringAsFixed(_cachePrecision)}_r${radiusKm.toInt()}";
    final now = DateTime.now();

    // 1. Check Memory Cache (10 minute TTL)
    if (_lastRequestTime.containsKey(cacheKey) &&
        now.difference(_lastRequestTime[cacheKey]!).inMinutes <
            _cacheTtlMinutes &&
        _dataCache.containsKey(cacheKey)) {
      debugPrint("API_SERVICE: Returning cached data for $cacheKey");
      return List.from(_dataCache[cacheKey]!);
    }

    // 2. Request Deduplication: If an identical request is in flight, join it
    if (_inflightRequests.containsKey(cacheKey)) {
      debugPrint("API_SERVICE: Joining in-flight request for $cacheKey");
      return _inflightRequests[cacheKey]!;
    }

    // 3. Debounce: queue the request
    return _debouncedFetch(
      cacheKey: cacheKey,
      lat: lat,
      lng: lng,
      category: category,
      radiusKm: radiusKm,
    );
  }

  Future<List<dynamic>> _debouncedFetch({
    required String cacheKey,
    required double lat,
    required double lng,
    required String? category,
    required double radiusKm,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    // Check cache again after async gap
    final now = DateTime.now();
    if (_dataCache.containsKey(cacheKey) &&
        _lastRequestTime.containsKey(cacheKey) &&
        now.difference(_lastRequestTime[cacheKey]!).inMinutes <
            _cacheTtlMinutes) {
      return List.from(_dataCache[cacheKey]!);
    }

    // Cancel existing debounce timer
    _debounceTimer?.cancel();

    // Create completer for this request
    final completer = Completer<List<dynamic>>();

    _pendingRequests[cacheKey] = _PendingRequest(
      completer: completer,
      lat: lat,
      lng: lng,
      category: category,
      radiusKm: radiusKm,
      idToken: idToken,
    );

    // Start debounce timer
    _debounceTimer = Timer(_debounceDelay, () => _flushPendingRequests());

    return completer.future;
  }

  void _flushPendingRequests() {
    final requests = Map<String, _PendingRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    for (final entry in requests.entries) {
      _performFetchNearbyDonations(
        lat: entry.value.lat,
        lng: entry.value.lng,
        category: entry.value.category,
        radiusKm: entry.value.radiusKm,
        idToken: entry.value.idToken,
        cacheKey: entry.key,
        completer: entry.value.completer,
      );
    }
  }

  Future<void> _performFetchNearbyDonations({
    required double lat,
    required double lng,
    required String? category,
    required double radiusKm,
    required String? idToken,
    required String cacheKey,
    required Completer<List<dynamic>> completer,
  }) async {
    try {
      debugPrint("API_SERVICE: Network fetch START for $cacheKey");

      final response = await http.post(
        Uri.parse(_nearbyDonationsUrl),
        headers: {
          "Content-Type": "application/json",
          if (idToken != null) "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "data": {
            "latitude": lat,
            "longitude": lng,
            "radiusKm": radiusKm,
            "limit": 10,
            if (category != null) "category": category,
          },
        }),
      );

      List<dynamic> result = [];
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        result = data['result']?['donations'] ?? [];

        _dataCache[cacheKey] = result;
        _lastRequestTime[cacheKey] = DateTime.now();
      }

      if (!completer.isCompleted) {
        completer.complete(result);
      }
    } catch (e) {
      debugPrint("API_SERVICE: Error fetching donations: $e");
      if (!completer.isCompleted) {
        completer.complete([]);
      }
    } finally {
      _inflightRequests.remove(cacheKey);
    }
  }

  Future<List<dynamic>> getReceivedItems(String tab) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final now = DateTime.now();
      if (_lastRequestTime.containsKey(tab) &&
          now.difference(_lastRequestTime[tab]!).inMinutes < 2 &&
          _dataCache.containsKey(tab)) {
        return List.from(_dataCache[tab]!);
      }

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse(_receivedItemsUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "data": {"tab": tab},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        dynamic resultData;
        if (data['result'] != null) {
          final result = data['result'];
          if (result is List) {
            resultData = result;
          } else if (result is Map) {
            resultData = result['transactions'] ?? result['items'] ?? [];
          }
        }

        final List<dynamic> transactions = resultData is List ? resultData : [];
        _dataCache[tab] = transactions;
        _lastRequestTime[tab] = DateTime.now();
        return transactions;
      }
      return [];
    } catch (e) {
      debugPrint("API_SERVICE: getReceivedItems EXCEPTION=$e");
      return [];
    }
  }

  Future<List<dynamic>> fetchMultipleCategories({
    required double lat,
    required double lng,
    required List<String> categories,
    double radiusKm = 10,
  }) async {
    List<dynamic> combinedDonations = [];
    final futures = categories.map(
      (cat) => fetchNearbyDonations(
        lat: lat,
        lng: lng,
        category: cat,
        radiusKm: radiusKm,
      ),
    );

    final results = await Future.wait(futures);
    for (var list in results) {
      combinedDonations.addAll(list);
    }
    return combinedDonations;
  }
}
