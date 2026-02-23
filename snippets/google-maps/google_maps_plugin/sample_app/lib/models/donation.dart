import 'package:google_maps_plugin/google_maps_plugin.dart';

/// Sample Donation model implementing MapMarkerItem
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

  // Additional fields specific to Donation
  final String description;
  final String donorName;
  final String condition;
  final String status;
  final DateTime createdAt;

  Donation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.title,
    this.snippet,
    required this.description,
    required this.donorName,
    required this.condition,
    required this.status,
    required this.createdAt,
  });

  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      id: json['id'] ?? '',
      latitude: (json['latitude'] ?? json['location']?['latitude'] ?? 0.0)
          .toDouble(),
      longitude: (json['longitude'] ?? json['location']?['longitude'] ?? 0.0)
          .toDouble(),
      category: json['category'] ?? 'other',
      title: json['title'] ?? 'Untitled',
      snippet:
          json['snippet'] ??
          json['description']?.toString().substring(
            0,
            json['description'].toString().length > 50
                ? 50
                : json['description'].toString().length,
          ),
      description: json['description'] ?? '',
      donorName: json['donorName'] ?? json['donor_name'] ?? 'Anonymous',
      condition: json['condition'] ?? 'good',
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'title': title,
      'snippet': snippet,
      'description': description,
      'donorName': donorName,
      'condition': condition,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Sample Store model demonstrating reusability of the plugin
class Store implements MapMarkerItem {
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

  final String storeType;
  final String phone;
  final bool isOpen;
  final double rating;

  Store({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.title,
    this.snippet,
    required this.storeType,
    required this.phone,
    required this.isOpen,
    required this.rating,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      category: json['category'] ?? 'store',
      title: json['title'] ?? json['name'] ?? 'Store',
      snippet: json['snippet'] ?? json['address'],
      storeType: json['storeType'] ?? 'general',
      phone: json['phone'] ?? '',
      isOpen: json['isOpen'] ?? false,
      rating: (json['rating'] ?? 0.0).toDouble(),
    );
  }
}
