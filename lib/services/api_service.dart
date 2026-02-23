import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

class ApiService {
  final String _baseUrl = "https://getnearbydonations-u6nq5a5ajq-as.a.run.app";

  Future<List<dynamic>> fetchNearbyDonations({
    required double lat,
    required double lng,
    String? category,
    double radiusKm = 10,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      debugPrint(
        "API_SERVICE_DEBUG: request lat=$lat lng=$lng radiusKm=$radiusKm category=${category ?? 'null'} token=${idToken == null ? 'null' : 'present'}",
      );

      final response = await http.post(
        Uri.parse(_baseUrl),
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

      debugPrint(
        "API_SERVICE_DEBUG: status=${response.statusCode} body=${response.body}",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("API_SERVICE_DEBUG: Parsed Data: $data");
        return data['result']?['donations'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint("API_SERVICE_DEBUG: exception=$e");
      return [];
    }
  }

  // NEW: Method to fetch and combine multiple categories
  Future<List<dynamic>> fetchMultipleCategories({
    required double lat,
    required double lng,
    required List<String> categories,
    double radiusKm = 10,
  }) async {
    List<dynamic> combinedDonations = [];
    for (String category in categories) {
      final donations = await fetchNearbyDonations(
        lat: lat,
        lng: lng,
        category: category,
        radiusKm: radiusKm,
      );
      combinedDonations.addAll(donations);
    }
    return combinedDonations;
  }

  // Helper for Urgent Blood (WF-11) - NOW DYNAMIC
  Future<List<dynamic>> fetchNearbyBloodRequests({
    required double lat,
    required double lng,
    double radiusKm = 50.0,
  }) {
    return fetchNearbyDonations(
      lat: lat,
      lng: lng,
      category: "blood",
      radiusKm: radiusKm,
    );
  }
}
