import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Singleton Pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _nearbyDonationsUrl = "https://getnearbydonations-u6nq5a5ajq-as.a.run.app";
  final String _receivedItemsUrl = "https://getreceiveditems-u6nq5a5ajq-as.a.run.app";

  // Cache and Request Deduplication
  final Map<String, DateTime> _lastRequestTime = {};
  final Map<String, List<dynamic>> _dataCache = {};
  final Map<String, Future<List<dynamic>>> _inflightRequests = {};

  Future<List<dynamic>> fetchNearbyDonations({
    required double lat,
    required double lng,
    String? category,
    double radiusKm = 10,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    
    // Normalize coordinates to 3 decimal places (~110m) to prevent jitter spam
    final cacheKey = "nearby_${category ?? 'all'}_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}";
    final now = DateTime.now();

    // 1. Check Memory Cache (5 minute TTL)
    if (_lastRequestTime.containsKey(cacheKey) && 
        now.difference(_lastRequestTime[cacheKey]!).inMinutes < 5 &&
        _dataCache.containsKey(cacheKey)) {
      debugPrint("API_SERVICE: Returning cached data for $cacheKey");
      return _dataCache[cacheKey]!;
    }

    // 2. Request Deduplication: If an identical request is in flight, join it
    if (_inflightRequests.containsKey(cacheKey)) {
      debugPrint("API_SERVICE: Joining in-flight request for $cacheKey");
      return _inflightRequests[cacheKey]!;
    }

    // 3. Perform the actual network call
    final fetchFuture = _performFetchNearbyDonations(
      lat: lat,
      lng: lng,
      category: category,
      radiusKm: radiusKm,
      idToken: idToken,
      cacheKey: cacheKey,
    );

    _inflightRequests[cacheKey] = fetchFuture;
    return fetchFuture;
  }

  Future<List<dynamic>> _performFetchNearbyDonations({
    required double lat,
    required double lng,
    required String? category,
    required double radiusKm,
    required String? idToken,
    required String cacheKey,
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['result']?['donations'] ?? [];
        
        _dataCache[cacheKey] = list;
        _lastRequestTime[cacheKey] = DateTime.now();
        return list;
      }
      return [];
    } catch (e) {
      debugPrint("API_SERVICE: Error fetching donations: $e");
      return [];
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
        return _dataCache[tab]!;
      }
      
      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse(_receivedItemsUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "data": {
            "tab": tab,
          },
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
    // Note: This still performs multiple calls internally but fetchNearbyDonations
    // will now handle caching and deduplication, making this much safer.
    List<dynamic> combinedDonations = [];
    final futures = categories.map((cat) => fetchNearbyDonations(
      lat: lat,
      lng: lng,
      category: cat,
      radiusKm: radiusKm,
    ));
    
    final results = await Future.wait(futures);
    for (var list in results) {
      combinedDonations.addAll(list);
    }
    return combinedDonations;
  }
}
