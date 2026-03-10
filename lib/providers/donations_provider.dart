// lib/providers/donations_provider.dart
// Riverpod providers for real-time donation data using Firestore streams
// Replaces cached API calls with live Firestore listeners

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for Firestore instance
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Provider for real-time blood requests stream
/// Uses Firestore .snapshots() for real-time updates
final bloodRequestsStreamProvider =
    StreamProvider.family<QuerySnapshot, ({double lat, double lng})>((
      ref,
      coords,
    ) {
      final firestore = ref.read(firestoreProvider);

      return firestore
          .collection('donations')
          .where('category', isEqualTo: 'blood')
          .where('status', isEqualTo: 'active')
          .orderBy('created_at', descending: true)
          .limit(5)
          .snapshots();
    });

/// Provider for real-time food donations stream
final foodDonationsStreamProvider =
    StreamProvider.family<QuerySnapshot, ({double lat, double lng})>((
      ref,
      coords,
    ) {
      final firestore = ref.read(firestoreProvider);

      return firestore
          .collection('donations')
          .where('category', isEqualTo: 'food')
          .where('status', isEqualTo: 'active')
          .orderBy('created_at', descending: true)
          .limit(5)
          .snapshots();
    });

/// Provider for real-time other items stream (appliances + stationery)
final otherItemsStreamProvider =
    StreamProvider.family<QuerySnapshot, ({double lat, double lng})>((
      ref,
      coords,
    ) {
      final firestore = ref.read(firestoreProvider);

      return firestore
          .collection('donations')
          .where('category', whereIn: ['appliances', 'stationery'])
          .where('status', isEqualTo: 'active')
          .orderBy('created_at', descending: true)
          .limit(5)
          .snapshots();
    });

/// Provider for all nearby donations (for search results)
final nearbyDonationsStreamProvider =
    StreamProvider.family<
      QuerySnapshot,
      ({double lat, double lng, String? category, double radiusKm})
    >((ref, params) {
      final firestore = ref.read(firestoreProvider);

      Query query = firestore
          .collection('donations')
          .where('status', isEqualTo: 'active')
          .orderBy('created_at', descending: true);

      if (params.category != null && params.category!.isNotEmpty) {
        query = query.where('category', isEqualTo: params.category);
      }

      return query.limit(50).snapshots();
    });

/// Provider to invalidate cache and trigger refresh
/// Call this when a new donation is created
class DonationRefreshNotifier extends StateNotifier<DateTime> {
  DonationRefreshNotifier() : super(DateTime.now());

  void refresh() {
    state = DateTime.now();
  }
}

/// Provider for donation refresh trigger
final donationRefreshProvider =
    StateNotifierProvider<DonationRefreshNotifier, DateTime>((ref) {
      return DonationRefreshNotifier();
    });

/// Combined provider that listens to refresh trigger and returns stream
/// This allows manual refresh while maintaining real-time updates
final refreshableBloodRequestsProvider =
    StreamProvider.family<QuerySnapshot, ({double lat, double lng})>((
      ref,
      coords,
    ) {
      // Listen to refresh trigger (this will rebuild the provider when refresh() is called)
      ref.watch(donationRefreshProvider);

      final firestore = ref.read(firestoreProvider);

      return firestore
          .collection('donations')
          .where('category', isEqualTo: 'blood')
          .where('status', isEqualTo: 'active')
          .orderBy('created_at', descending: true)
          .limit(5)
          .snapshots();
    });

final refreshableFoodDonationsProvider =
    StreamProvider.family<QuerySnapshot, ({double lat, double lng})>((
      ref,
      coords,
    ) {
      ref.watch(donationRefreshProvider);

      final firestore = ref.read(firestoreProvider);

      return firestore
          .collection('donations')
          .where('category', isEqualTo: 'food')
          .where('status', isEqualTo: 'active')
          .orderBy('created_at', descending: true)
          .limit(5)
          .snapshots();
    });

final refreshableOtherItemsProvider =
    StreamProvider.family<QuerySnapshot, ({double lat, double lng})>((
      ref,
      coords,
    ) {
      ref.watch(donationRefreshProvider);

      final firestore = ref.read(firestoreProvider);

      return firestore
          .collection('donations')
          .where('category', whereIn: ['appliances', 'stationery'])
          .where('status', isEqualTo: 'active')
          .orderBy('created_at', descending: true)
          .limit(5)
          .snapshots();
    });

/// Extension to convert QuerySnapshot to List<Map<String, dynamic>>
extension QuerySnapshotExtension on QuerySnapshot {
  List<Map<String, dynamic>> toDonationList() {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}
