import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================
// USER MODEL
// Matches backend User type
// ============================================

class UserModel {
  final String uid;
  final String phone;
  String? name;
  String? email;
  String? bloodGroup;
  String? profilePicture;
  String? bio;
  
  // Location
  String? address;
  String? area;
  double? latitude;
  double? longitude;

  // Trust & Gamification
  final int karmaPoints;
  final List<String> badges;
  final int trustScore;
  final int priorityPasses;

  // Stats
  final int totalDonations;
  final int totalReceived;
  final double averageRating;

  // Activity
  final DateTime createdAt;
  DateTime lastActive;

  // Moderation
  final bool isBanned;
  final String? banReason;
  final int warningsCount;

  // Privacy

  final bool phoneVisible;
  final bool emailVisible;
  final bool profilePicVisible;

  UserModel({
    required this.uid,
    required this.phone,

    this.name,
    this.email,
    this.bloodGroup,
    this.profilePicture,
    this.bio,
    this.address,
    this.area,
    this.latitude,
    this.longitude,

    this.karmaPoints = 0,
    this.badges = const [],
    this.trustScore = 50,
    this.priorityPasses = 0,

    this.totalDonations = 0,
    this.totalReceived = 0,
    this.averageRating = 0.0,

    required this.createdAt,
    required this.lastActive,

    this.isBanned = false,
    this.banReason,
    this.warningsCount = 0,

    this.phoneVisible = false,
    this.emailVisible = false,
    this.profilePicVisible = true,
  });

  // ============================================
  // FROM FIRESTORE DOCUMENT
  // ============================================

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    double? lat;
    double? lng;
    
    if (data['location'] is GeoPoint) {
      lat = (data['location'] as GeoPoint).latitude;
      lng = (data['location'] as GeoPoint).longitude;
    }

    return UserModel(
      uid: doc.id,
      phone: data['phone'] ?? '',
      name: data['name'],
      email: data['email'],
      bloodGroup: data['bloodGroup'],
      profilePicture: data['profilePicture'],
      bio: data['bio'],
      address: data['address'],
      area: data['area'],
      latitude: lat,
      longitude: lng,

      karmaPoints: data['karma_points'] ?? 0,
      badges: List<String>.from(data['badges'] ?? []),
      trustScore: data['trust_score'] ?? 50,
      priorityPasses: data['priority_passes'] ?? 0,

      totalDonations: data['total_donations'] ?? 0,
      totalReceived: data['total_received'] ?? 0,
      averageRating: (data['average_rating'] ?? 0.0).toDouble(),

      createdAt: data['created_at'] != null 
          ? (data['created_at'] as Timestamp).toDate() 
          : DateTime.now(),
      lastActive: data['last_active'] != null 
          ? (data['last_active'] as Timestamp).toDate() 
          : DateTime.now(),

      isBanned: data['is_banned'] ?? false,
      banReason: data['ban_reason'],
      warningsCount: data['warnings_count'] ?? 0,
      phoneVisible: data['phone_visible'] ?? false,
      emailVisible: data['email_visible'] ?? false,
      profilePicVisible: data['picture_visible'] ?? true,
    );
  }

  // ============================================
  // TO FIRESTORE DOCUMENT
  // ============================================

  Map<String, dynamic> toFireStore() {
    return {
      'uid': uid,
      'phone': phone,
      'name': name,
      'email': email,
      'bloodGroup': bloodGroup,
      'profilePicture': profilePicture,
      'bio': bio,
      'address': address,
      'area': area,
      'location': (latitude != null && longitude != null) 
          ? GeoPoint(latitude!, longitude!) 
          : null,

      'karma_points': karmaPoints,
      'badges': badges,
      'trust_score': trustScore,
      'priority_passes': priorityPasses,

      'total_donations': totalDonations,
      'total_received': totalReceived,
      'average_rating': averageRating,

      'created_at': Timestamp.fromDate(createdAt),
      'last_active': Timestamp.fromDate(lastActive),

      'is_banned': isBanned,
      'ban_reason': banReason,
      'warnings_count': warningsCount,

      'phone_visible': phoneVisible,
      'email_visible': emailVisible,
      'picture_visible': profilePicVisible,
    };
  }
}
