import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const bool _kDebugLogging = false;

void _log(String message) {
  if (_kDebugLogging && kDebugMode) {
    debugPrint(message);
  }
}

class _PendingRequest {
  final Completer<List<dynamic>> completer;
  final double? lat;
  final double? lng;
  final String? category;
  final String? searchQuery;
  final double? radiusKm;
  final int? limit;
  final String? idToken;

  _PendingRequest({
    required this.completer,
    this.lat,
    this.lng,
    this.category,
    this.searchQuery,
    this.radiusKm,
    this.limit,
    this.idToken,
  });
}

class ApiService {
  // Singleton Pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  final String _nearbyDonationsUrl =
      "https://getnearbydonations-u6nq5a5ajq-as.a.run.app";
  final String _receivedItemsUrl =
      "https://getreceiveditems-u6nq5a5ajq-as.a.run.app";
  final String _searchDonationsUrl =
      "https://searchdonations-u6nq5a5ajq-as.a.run.app";
  final String _notificationsUrl =
      "https://getnotifications-u6nq5a5ajq-as.a.run.app";
  final String _getUserChatsUrl =
      "https://getuserchats-u6nq5a5ajq-as.a.run.app";
  final String _getChatMessagesUrl =
      "https://getchatmessages-u6nq5a5ajq-as.a.run.app";
  final String _sendMessageUrl = "https://sendmessage-u6nq5a5ajq-as.a.run.app";

  // Cache and Request Deduplication
  final Map<String, DateTime> _lastRequestTime = {};
  final Map<String, List<dynamic>> _dataCache = {};
  final Map<String, Future<List<dynamic>>> _inflightRequests = {};

  /// Clears all cached data. Call this when new donations are created.
  void clearCache() {
    _dataCache.clear();
    _lastRequestTime.clear();
    _inflightRequests.clear();
    _debounceTimer?.cancel();
    _pendingRequests.clear();
    debugPrint("API_SERVICE: Cache cleared");
  }

  /// Clears cache for nearby donations only
  void clearNearbyDonationsCache() {
    _dataCache.removeWhere((key, _) => key.startsWith('nearby_'));
    _lastRequestTime.removeWhere((key, _) => key.startsWith('nearby_'));
    debugPrint("API_SERVICE: Nearby donations cache cleared");
  }

  // Debouncing - single timer for all requests
  Timer? _debounceTimer;
  final Map<String, _PendingRequest> _pendingRequests = {};

  static const Duration _debounceDelay = Duration(milliseconds: 500);
  static const int _cachePrecision = 2; // ~1.1km precision
  static const int _cacheTtlMinutes = 10;

  /// Helper to get App Check token for raw HTTP requests
  Future<String?> _getAppCheckToken() async {
    try {
      return await FirebaseAppCheck.instance.getToken();
    } catch (e) {
      debugPrint("API_SERVICE: Failed to get App Check token: $e");
      return null;
    }
  }

  Future<List<dynamic>> fetchNearbyDonations({
    required double lat,
    required double lng,
    String? category,
    double radiusKm = 10,
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        "nearby_${category ?? 'all'}_${lat.toStringAsFixed(_cachePrecision)}_${lng.toStringAsFixed(_cachePrecision)}_r${radiusKm.toInt()}_l$limit";
    final now = DateTime.now();

    if (!forceRefresh &&
        _lastRequestTime.containsKey(cacheKey) &&
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
      limit: limit,
    );
  }

  Future<List<dynamic>> searchDonations({
    String? searchQuery,
    double? lat,
    double? lng,
    int limit = 20,
  }) async {
    final query = (searchQuery ?? "").trim();
    final cacheKey = "search_fuzzy_${query.toLowerCase()}_l$limit";
    final now = DateTime.now();

    if (_lastRequestTime.containsKey(cacheKey) &&
        now.difference(_lastRequestTime[cacheKey]!).inMinutes < 2 &&
        _dataCache.containsKey(cacheKey)) {
      debugPrint(
        "API_SERVICE: Returning cached fuzzy search results for $cacheKey",
      );
      return List.from(_dataCache[cacheKey]!);
    }

    return _debouncedFetch(
      cacheKey: cacheKey,
      searchQuery: query,
      lat: lat,
      lng: lng,
      radiusKm: 0, // Not used for search
      limit: limit,
    );
  }

  Future<List<dynamic>> _debouncedFetch({
    required String cacheKey,
    double? lat,
    double? lng,
    String? category,
    String? searchQuery,
    double? radiusKm,
    int? limit,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _log('API_SERVICE: No current user');
      return [];
    }

    String? idToken;
    try {
      idToken = await user.getIdToken(true);
    } catch (e) {
      _log('API_SERVICE: Failed to get ID token: $e');
      return [];
    }

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
      limit: limit,
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
          limit: entry.value.limit ?? 20,
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
          limit: entry.value.limit ?? 10,
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

      final appCheckToken = await _getAppCheckToken();

      final response = await http.post(
        Uri.parse(_searchDonationsUrl),
        headers: {
          "Content-Type": "application/json",
          "X-Firebase-AppCheck": appCheckToken ?? "",
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
          extracted =
              extracted['donations'] ??
              extracted['items'] ??
              extracted['results'] ??
              extracted['donations_list'];
        }

        result = extracted is List ? extracted : [];

        if (query.isNotEmpty) {
          result = result.where((item) {
            final title = (item['title'] ?? "").toString().toLowerCase();
            final category = (item['category'] ?? "").toString().toLowerCase();
            final description = (item['description'] ?? "")
                .toString()
                .toLowerCase();

            return title.contains(query) ||
                category.contains(query) ||
                description.contains(query);
          }).toList();
        }

        _dataCache[cacheKey] = result;
        _lastRequestTime[cacheKey] = DateTime.now();
      } else {
        debugPrint(
          "API_SERVICE: Search HTTP ERROR ${response.statusCode}: ${response.body}",
        );
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
    required int limit,
    required String? idToken,
    required String cacheKey,
    required Completer<List<dynamic>> completer,
  }) async {
    try {
      debugPrint(
        "API_SERVICE: Network fetch START for $cacheKey with limit $limit",
      );
      
      final appCheckToken = await _getAppCheckToken();

      final response = await http.post(
        Uri.parse(_nearbyDonationsUrl),
        headers: {
          "Content-Type": "application/json",
          "X-Firebase-AppCheck": appCheckToken ?? "",
          if (idToken != null) "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "data": {
            "latitude": lat,
            "longitude": lng,
            "radiusKm": radiusKm,
            "limit": limit,
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
      if (!completer.isCompleted) completer.complete([]);
    } finally {
      _inflightRequests.remove(cacheKey);
    }
  }

  Future<List<dynamic>> getNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("API_SERVICE: getNotifications - No user logged in");
        return [];
      }

      // Force refresh token if needed
      final idToken = await user.getIdToken(true).catchError((e) {
        debugPrint("API_SERVICE: getNotifications - Failed to get token: $e");
        return null;
      });

      if (idToken == null) {
        debugPrint("API_SERVICE: getNotifications - Token is null");
        return [];
      }

      final appCheckToken = await _getAppCheckToken();

      debugPrint("API_SERVICE: getNotifications - Fetching from server...");

      // Add timeout to prevent hanging
      final response = await http
          .post(
            Uri.parse(_notificationsUrl),
            headers: {
              "Content-Type": "application/json",
              "X-Firebase-AppCheck": appCheckToken ?? "",
              "Authorization": "Bearer $idToken",
            },
            body: jsonEncode({"data": {}}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint("API_SERVICE: getNotifications TIMEOUT");
              throw TimeoutException('Request timed out after 10 seconds');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'] ?? [];
        debugPrint(
          "API_SERVICE: getNotifications SUCCESS - ${result.length} notifications",
        );
        return result is List ? result : [];
      } else if (response.statusCode == 401) {
        debugPrint("API_SERVICE: getNotifications UNAUTHORIZED (401)");
        // App Check might be rejecting - return empty
        return [];
      } else {
        debugPrint("API_SERVICE: getNotifications HTTP ${response.statusCode}");
        return [];
      }
    } on TimeoutException catch (e) {
      debugPrint("API_SERVICE: getNotifications TIMEOUT_EXCEPTION=$e");
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
      final appCheckToken = await _getAppCheckToken();

      final response = await http.post(
        Uri.parse(_receivedItemsUrl),
        headers: {
          "Content-Type": "application/json",
          "X-Firebase-AppCheck": appCheckToken ?? "",
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

        // Ensure each transaction has an ID field
        final List<dynamic> transactionsWithIds = transactions.map((tx) {
          if (tx is Map<String, dynamic>) {
            final txId = tx['id'] ?? tx['transactionId'] ?? tx['documentId'];
            if (txId == null) {
              // Generate a fallback ID from donationId + receiverId + timestamp
              final fallbackId = '${tx['donationId']}_${tx['receiverId']}';
              return {...tx, 'id': fallbackId, 'transactionId': fallbackId};
            }
            return {...tx, 'id': txId, 'transactionId': txId};
          }
          return tx;
        }).toList();

        _dataCache[tab] = transactionsWithIds;
        _lastRequestTime[tab] = DateTime.now();
        return transactionsWithIds;
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
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    List<dynamic> combinedDonations = [];
    final results = await Future.wait(
      categories.map(
        (cat) => fetchNearbyDonations(
          lat: lat,
          lng: lng,
          category: cat,
          radiusKm: radiusKm,
          limit: limit,
          forceRefresh: forceRefresh,
        ),
      ),
    );
    for (var list in results) {
      combinedDonations.addAll(list);
    }
    // Re-sort by distance if multiple categories mixed up the order
    combinedDonations.sort((a, b) {
      final distA = a['distance'] ?? 999;
      final distB = b['distance'] ?? 999;
      return distA.compareTo(distB);
    });
    return combinedDonations;
  }

  Future<Map<String, dynamic>> getChatMessages(
    String donationId, {
    int limit = 20,
    String? lastTimestamp,
    String? requesterId,
  }) async {
    try {
      _log('API_SERVICE: === getChatMessages START ===');
      _log('API_SERVICE: donationId = $donationId');
      _log('API_SERVICE: requesterId = $requesterId');
      _log('API_SERVICE: limit = $limit');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log('API_SERVICE: No current user');
        return {"messages": [], "hasMore": false, "error": "Not authenticated"};
      }

      String? idToken;
      try {
        idToken = await user.getIdToken(true);
      } catch (e) {
        _log('API_SERVICE: Failed to get ID token: $e');
        return {
          "messages": [],
          "hasMore": false,
          "error": "Auth token refresh failed",
        };
      }

      final requestBody = {
        "data": {
          "donationId": donationId,
          "limit": limit,
          if (lastTimestamp != null) "lastTimestamp": lastTimestamp,
          if (requesterId != null) "requesterId": requesterId,
        },
      };

      _log('API_SERVICE: Request body = $requestBody');

      final appCheckToken = await _getAppCheckToken();

      final response = await http
          .post(
            Uri.parse(_getChatMessagesUrl),
            headers: {
              "Content-Type": "application/json",
              "X-Firebase-AppCheck": appCheckToken ?? "",
              "Authorization": "Bearer $idToken",
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      _log('API_SERVICE: Response status = ${response.statusCode}');
      _log('API_SERVICE: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'] ?? data;

        return {
          "messages": result['messages'] ?? [],
          "lastTimestamp": result['lastTimestamp'],
          "hasMore": result['hasMore'] ?? false,
        };
      } else {
        _log('API_SERVICE: HTTP ERROR ${response.statusCode}');
        return {
          "messages": [],
          "hasMore": false,
          "error": "HTTP ${response.statusCode}",
        };
      }
    } catch (e, stack) {
      _log('API_SERVICE: getChatMessages ERROR = $e');
      _log('API_SERVICE: Stack = $stack');
      return {"messages": [], "hasMore": false, "error": e.toString()};
    }
  }

  Future<List<dynamic>> getUserChats({String filter = 'all'}) async {
    try {
      _log('API_SERVICE: Calling getUserChats with filter: $filter...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log('API_SERVICE: No current user');
        return [];
      }

      String? idToken;
      try {
        idToken = await user.getIdToken(true);
      } catch (e) {
        _log('API_SERVICE: Failed to get ID token: $e');
        return [];
      }

      final appCheckToken = await _getAppCheckToken();

      final response = await http
          .post(
            Uri.parse(_getUserChatsUrl),
            headers: {
              "Content-Type": "application/json",
              "X-Firebase-AppCheck": appCheckToken ?? "",
              "Authorization": "Bearer $idToken",
            },
            body: jsonEncode({
              "data": {"filter": filter},
            }),
          )
          .timeout(const Duration(seconds: 30));

      _log('API_SERVICE: getUserChats status = ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'] ?? data;
        final chats = result['chats'] ?? [];
        _log('API_SERVICE: Found ${chats.length} chats');
        return chats;
      } else {
        debugPrint(
          'API_SERVICE: getUserChats HTTP ERROR ${response.statusCode}',
        );
        return [];
      }
    } catch (e, stack) {
      _log('API_SERVICE: getUserChats ERROR: $e');
      _log('API_SERVICE: Stack trace: $stack');
      return [];
    }
  }

  Future<bool> sendMessage(
    String donationId,
    String message, {
    String? requesterId,
  }) async {
    try {
      _log('API_SERVICE: Sending message...');

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      if (idToken == null) {
        _log('API_SERVICE: No idToken available');
        return false;
      }

      final appCheckToken = await _getAppCheckToken();

      final response = await http
          .post(
            Uri.parse(_sendMessageUrl),
            headers: {
              "Content-Type": "application/json",
              "X-Firebase-AppCheck": appCheckToken ?? "",
              "Authorization": "Bearer $idToken",
            },
            body: jsonEncode({
              "data": {
                "donationId": donationId,
                "message": message,
                if (requesterId != null) "requesterId": requesterId,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'] ?? data;
        return result['success'] ?? false;
      }
      return false;
    } catch (e) {
      _log('API_SERVICE: sendMessage ERROR: $e');
      return false;
    }
  }

  Future<bool> markMessageAsRead(String donationId, String messageId) async {
    try {
      final result = await _functions.httpsCallable('markMessageAsRead').call({
        "donationId": donationId,
        "messageId": messageId,
      });
      return result.data['success'] ?? false;
    } catch (e) {
      _log('API_SERVICE: markMessageAsRead ERROR: $e');
      return false;
    }
  }

  Future<bool> archiveChatMessages(String donationId) async {
    try {
      final result = await _functions.httpsCallable('archiveChatMessages').call(
        {"donationId": donationId},
      );
      return result.data['success'] ?? false;
    } catch (e) {
      _log('API_SERVICE: archiveChatMessages ERROR: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getTransaction(String transactionId) async {
    try {
      _log('API_SERVICE: Calling getTransaction Cloud Function...');
      final result = await _functions.httpsCallable('getTransaction').call({
        "transactionId": transactionId,
      });
      _log('API_SERVICE: getTransaction result: ${result.data}');
      return result.data;
    } catch (e) {
      _log('API_SERVICE: getTransaction ERROR: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTransactionByDonation(
    String donationId,
  ) async {
    try {
      debugPrint(
        'API_SERVICE: Calling getTransactionByDonation Cloud Function...',
      );
      final result = await _functions
          .httpsCallable('getTransactionByDonation')
          .call({"donationId": donationId});
      debugPrint(
        'API_SERVICE: getTransactionByDonation result: ${result.data}',
      );
      return result.data;
    } catch (e) {
      _log('API_SERVICE: getTransactionByDonation ERROR: $e');
      return null;
    }
  }
}
