import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class _PendingRequest {
  final Completer<List<dynamic>> completer;
  final double? lat;
  final double? lng;
  final String? category;
  final String? searchQuery;
  final double? radiusKm;
  final String? idToken;

  _PendingRequest({
    required this.completer,
    this.lat,
    this.lng,
    this.category,
    this.searchQuery,
    this.radiusKm,
    this.idToken,
  });
}

class ApiService {
  // Singleton Pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final String _nearbyDonationsUrl =
      "https://getnearbydonations-u6nq5a5ajq-as.a.run.app";
  final String _receivedItemsUrl =
      "https://getreceiveditems-u6nq5a5ajq-as.a.run.app";
  final String _searchDonationsUrl =
      "https://searchdonations-u6nq5a5ajq-as.a.run.app";
  final String _notificationsUrl = 
      "https://getnotifications-u6nq5a5ajq-as.a.run.app";

  // Cache and Request Deduplication
  final Map<String, DateTime> _lastRequestTime = {};
  final Map<String, List<dynamic>> _dataCache = {};
  final Map<String, Future<List<dynamic>>> _inflightRequests = {};

  // Debouncing - single timer for all requests
  Timer? _debounceTimer;
  final Map<String, _PendingRequest> _pendingRequests = {};

  static const Duration _debounceDelay = Duration(milliseconds: 500);
  static const int _cachePrecision = 2; // ~1.1km precision
  static const int _cacheTtlMinutes = 10;

  Future<List<dynamic>> fetchNearbyDonations({
    required double lat,
    required double lng,
    String? category,
    double radiusKm = 10,
  }) async {
    final cacheKey =
        "nearby_${category ?? 'all'}_${lat.toStringAsFixed(_cachePrecision)}_${lng.toStringAsFixed(_cachePrecision)}_r${radiusKm.toInt()}";
    final now = DateTime.now();

    if (_lastRequestTime.containsKey(cacheKey) &&
        now.difference(_lastRequestTime[cacheKey]!).inMinutes <
            _cacheTtlMinutes &&
        _dataCache.containsKey(cacheKey)) {
      return List.from(_dataCache[cacheKey]!);
    }

    if (_inflightRequests.containsKey(cacheKey)) {
      return _inflightRequests[cacheKey]!;
    }

    return _debouncedFetch(
      cacheKey: cacheKey,
      lat: lat,
      lng: lng,
      category: category,
      radiusKm: radiusKm,
    );
  }

  Future<List<dynamic>> searchDonations({
    String? searchQuery,
    double? lat,
    double? lng,
    int limit = 20,
  }) async {
    final query = (searchQuery ?? "").trim();
    // Cache key for search is query-specific
    final cacheKey = "search_fuzzy_${query.toLowerCase()}_l$limit";
    final now = DateTime.now();

    if (_lastRequestTime.containsKey(cacheKey) &&
        now.difference(_lastRequestTime[cacheKey]!).inMinutes < 2 &&
        _dataCache.containsKey(cacheKey)) {
      debugPrint("API_SERVICE: Returning cached fuzzy search results for $cacheKey");
      return List.from(_dataCache[cacheKey]!);
    }

    return _debouncedFetch(
      cacheKey: cacheKey,
      searchQuery: query,
      lat: lat,
      lng: lng,
      radiusKm: limit.toDouble(), 
    );
  }

  Future<List<dynamic>> _debouncedFetch({
    required String cacheKey,
    double? lat,
    double? lng,
    String? category,
    String? searchQuery,
    double? radiusKm,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    final now = DateTime.now();
    if (_dataCache.containsKey(cacheKey) &&
        _lastRequestTime.containsKey(cacheKey) &&
        now.difference(_lastRequestTime[cacheKey]!).inMinutes <
            _cacheTtlMinutes) {
      return List.from(_dataCache[cacheKey]!);
    }

    _debounceTimer?.cancel();
    final completer = Completer<List<dynamic>>();

    if (cacheKey.startsWith("search_")) {
      _pendingRequests.removeWhere((key, value) => key.startsWith("search_"));
    }

    _pendingRequests[cacheKey] = _PendingRequest(
      completer: completer,
      lat: lat,
      lng: lng,
      category: category,
      searchQuery: searchQuery,
      radiusKm: radiusKm,
      idToken: idToken,
    );

    _debounceTimer = Timer(_debounceDelay, () => _flushPendingRequests());

    return completer.future;
  }

  void _flushPendingRequests() {
    final requests = Map<String, _PendingRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    for (final entry in requests.entries) {
      if (entry.key.startsWith("search_")) {
        _performSearchDonations(
          searchQuery: entry.value.searchQuery,
          lat: entry.value.lat,
          lng: entry.value.lng,
          limit: entry.value.radiusKm?.toInt() ?? 20,
          idToken: entry.value.idToken,
          cacheKey: entry.key,
          completer: entry.value.completer,
        );
      } else {
        _performFetchNearbyDonations(
          lat: entry.value.lat ?? 0,
          lng: entry.value.lng ?? 0,
          category: entry.value.category,
          radiusKm: entry.value.radiusKm ?? 10,
          idToken: entry.value.idToken,
          cacheKey: entry.key,
          completer: entry.value.completer,
        );
      }
    }
  }

  Future<void> _performSearchDonations({
    required String? searchQuery,
    required double? lat,
    required double? lng,
    required int limit,
    required String? idToken,
    required String cacheKey,
    required Completer<List<dynamic>> completer,
  }) async {
    try {
      final query = (searchQuery ?? "").toLowerCase().trim();
      debugPrint("API_SERVICE: Fuzzy Search START for query: '$query'");

      final response = await http.post(
        Uri.parse(_searchDonationsUrl),
        headers: {
          "Content-Type": "application/json",
          if (idToken != null) "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "data": {
            if (query.length > 5) "searchQuery": searchQuery,
            "limit": 100, 
          },
        }),
      );

      List<dynamic> result = [];
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        dynamic extracted = data['result'];
        if (extracted is Map) {
          extracted = extracted['donations'] ?? extracted['items'] ?? extracted['results'] ?? extracted['donations_list'];
        }

        result = extracted is List ? extracted : [];
        
        // --- LOCAL FUZZY FILTERING ---
        if (query.isNotEmpty) {
          result = result.where((item) {
            final title = (item['title'] ?? "").toString().toLowerCase();
            final category = (item['category'] ?? "").toString().toLowerCase();
            final description = (item['description'] ?? "").toString().toLowerCase();
            
            return title.contains(query) || 
                   category.contains(query) || 
                   description.contains(query);
          }).toList();
        }

        _dataCache[cacheKey] = result;
        _lastRequestTime[cacheKey] = DateTime.now();
      } else {
        debugPrint("API_SERVICE: Search HTTP ERROR ${response.statusCode}: ${response.body}");
      }

      if (!completer.isCompleted) completer.complete(result);
    } catch (e) {
      debugPrint("API_SERVICE: Search EXCEPTION for '$searchQuery': $e");
      if (!completer.isCompleted) completer.complete([]);
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

      if (!completer.isCompleted) completer.complete(result);
    } catch (e) {
      if (!completer.isCompleted) completer.complete([]);
    } finally {
      _inflightRequests.remove(cacheKey);
    }
  }

  Future<List<dynamic>> getNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse(_notificationsUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "data": {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'] ?? [];
        return result is List ? result : [];
      }
      return [];
    } catch (e) {
      debugPrint("API_SERVICE: getNotifications EXCEPTION=$e");
      return [];
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
    final results = await Future.wait(categories.map(
      (cat) => fetchNearbyDonations(lat: lat, lng: lng, category: cat, radiusKm: radiusKm),
    ));
    for (var list in results) {
      combinedDonations.addAll(list);
    }
    return combinedDonations;
  }

  Future<bool> sendMessage(String donationId, String message) async {
    try {
      final result = await _functions.httpsCallable('sendMessage').call({
        "donationId": donationId,
        "message": message,
      });
      return result.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getChatMessages(String donationId, {int limit = 20, String? lastTimestamp}) async {
    try {
      final result = await _functions.httpsCallable('getChatMessages').call({
        "donationId": donationId,
        "limit": limit,
        if (lastTimestamp != null) "lastTimestamp": lastTimestamp,
      });
      final data = result.data;
      return {
        "messages": data['messages'] ?? [],
        "lastTimestamp": data['lastTimestamp'],
        "hasMore": data['hasMore'] ?? false,
      };
    } catch (e) {
      return {"messages": [], "hasMore": false};
    }
  }

  Future<List<dynamic>> getChatList() async {
    try {
      final result = await _functions.httpsCallable('getChatList').call({});
      return result.data['chats'] ?? [];
    } catch (e) {
      return [];
    }
  }
}
