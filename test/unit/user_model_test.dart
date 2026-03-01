import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:givelocally_app/models/user_model.dart';

class MockDocumentSnapshot extends Mock implements DocumentSnapshot {}

void main() {
  group('UserModel', () {
    late MockDocumentSnapshot mockDoc;

    setUp(() {
      mockDoc = MockDocumentSnapshot();
    });

    test('creates model with required fields', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'test-uid',
        phone: '+919876543210',
        createdAt: now,
        lastActive: now,
      );

      expect(user.uid, 'test-uid');
      expect(user.phone, '+919876543210');
      expect(user.karmaPoints, 0);
      expect(user.trustScore, 50);
      expect(user.isBanned, false);
    });

    test('creates model with default values', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'test-uid',
        phone: '+919876543210',
        createdAt: now,
        lastActive: now,
      );

      expect(user.badges, []);
      expect(user.totalDonations, 0);
      expect(user.totalReceived, 0);
      expect(user.averageRating, 0.0);
    });

    test('fromFirestore parses all fields correctly', () {
      final now = DateTime.now();
      when(() => mockDoc.id).thenReturn('test-uid');
      when(() => mockDoc.data()).thenReturn({
        'phone': '+919876543210',
        'name': 'Test User',
        'email': 'test@example.com',
        'bloodGroup': 'O+',
        'profilePicture': 'https://example.com/photo.jpg',
        'bio': 'Test bio',
        'address': 'Hyderabad',
        'area': 'Gachibowli',
        'location': GeoPoint(17.385044, 78.486671),
        'karma_points': 100,
        'badges': ['first_donor', 'helper'],
        'trust_score': 75,
        'priority_passes': 2,
        'total_donations': 5,
        'total_received': 3,
        'average_rating': 4.5,
        'created_at': Timestamp.fromDate(now),
        'last_active': Timestamp.fromDate(now),
        'is_banned': false,
        'ban_reason': null,
        'warnings_count': 0,
        'phone_visible': true,
        'email_visible': false,
        'picture_visible': true,
      });

      final user = UserModel.fromFirestore(mockDoc);

      expect(user.uid, 'test-uid');
      expect(user.name, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.bloodGroup, 'O+');
      expect(user.karmaPoints, 100);
      expect(user.badges, ['first_donor', 'helper']);
      expect(user.trustScore, 75);
      expect(user.latitude, 17.385044);
      expect(user.longitude, 78.486671);
    });

    test('toFirestore serializes correctly', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'test-uid',
        phone: '+919876543210',
        name: 'Test User',
        karmaPoints: 100,
        trustScore: 75,
        latitude: 17.385044,
        longitude: 78.486671,
        createdAt: now,
        lastActive: now,
      );

      final data = user.toFireStore();

      expect(data['uid'], 'test-uid');
      expect(data['phone'], '+919876543210');
      expect(data['name'], 'Test User');
      expect(data['karma_points'], 100);
      expect(data['trust_score'], 75);
      expect(data['location'], isA<GeoPoint>());
      expect((data['location'] as GeoPoint).latitude, 17.385044);
    });

    test('handles missing optional fields', () {
      final now = DateTime.now();
      when(() => mockDoc.id).thenReturn('test-uid');
      when(() => mockDoc.data()).thenReturn({
        'phone': '+919876543210',
        'created_at': Timestamp.fromDate(now),
        'last_active': Timestamp.fromDate(now),
      });

      final user = UserModel.fromFirestore(mockDoc);

      expect(user.name, null);
      expect(user.email, null);
      expect(user.latitude, null);
      expect(user.longitude, null);
    });

    test('location is null when not provided in toFireStore', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'test-uid',
        phone: '+919876543210',
        createdAt: now,
        lastActive: now,
      );

      final data = user.toFireStore();
      expect(data['location'], null);
    });
  });
}
