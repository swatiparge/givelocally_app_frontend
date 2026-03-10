import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Diagnostic tool to test Firestore rules
///
/// Run this in your app to verify rules are working:
///
/// ```dart
/// await FirestoreDiagnostics.runDiagnostics();
/// ```
class FirestoreDiagnostics {
  static Future<void> runDiagnostics() async {
    debugPrint('🔍 Running Firestore Diagnostics...\n');

    final results = <String>[];

    // Test 1: Can we read our own user document?
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        results.add('✅ User document read: PASSED');
      } else {
        results.add('⚠️ User document read: SKIPPED (not logged in)');
      }
    } catch (e) {
      results.add('❌ User document read: FAILED - $e');
    }

    // Test 2: Can we query donations?
    try {
      await FirebaseFirestore.instance
          .collection('donations')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      results.add('✅ Donations query: PASSED');
    } catch (e) {
      results.add('❌ Donations query: FAILED - $e');
    }

    // Test 3: Can we query transactions as donor?
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('transactions')
            .where('donorId', isEqualTo: user.uid)
            .limit(1)
            .get();
        results.add('✅ Transactions query (as donor): PASSED');
      } else {
        results.add('⚠️ Transactions query: SKIPPED (not logged in)');
      }
    } catch (e) {
      results.add('❌ Transactions query: FAILED - $e');
    }

    // Test 4: Can we query transactions as receiver?
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('transactions')
            .where('receiverId', isEqualTo: user.uid)
            .limit(1)
            .get();
        results.add('✅ Transactions query (as receiver): PASSED');
      } else {
        results.add('⚠️ Transactions query: SKIPPED (not logged in)');
      }
    } catch (e) {
      results.add('❌ Transactions query: FAILED - $e');
    }

    // Test 5: Can we read a specific transaction?
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final transQuery = await FirebaseFirestore.instance
            .collection('transactions')
            .where('donorId', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (transQuery.docs.isNotEmpty) {
          final transId = transQuery.docs.first.id;
          await FirebaseFirestore.instance
              .collection('transactions')
              .doc(transId)
              .get();
          results.add('✅ Single transaction read: PASSED');
        } else {
          results.add(
            '⚠️ Single transaction read: SKIPPED (no transactions found)',
          );
        }
      } else {
        results.add('⚠️ Single transaction read: SKIPPED (not logged in)');
      }
    } catch (e) {
      results.add('❌ Single transaction read: FAILED - $e');
    }

    // Print results
    debugPrint('📊 Diagnostic Results:\n');
    for (final result in results) {
      debugPrint(result);
    }

    debugPrint('\n✅ Diagnostics complete!');

    // Count failures
    final failures = results.where((r) => r.startsWith('❌')).length;
    if (failures == 0) {
      debugPrint(
        '\n🎉 All tests passed! Firestore rules are working correctly.',
      );
    } else {
      debugPrint('\n⚠️  $failures test(s) failed. Check the errors above.');
      debugPrint('\n💡 Common fixes:');
      debugPrint(
        '   1. Make sure you deployed the rules: ./deploy_firebase_rules.sh',
      );
      debugPrint('   2. Wait 1-2 minutes after deployment');
      debugPrint('   3. Clear app data and restart');
      debugPrint('   4. Check Firebase Console > Firestore > Rules');
    }
  }
}

// Note: Add this import to use FirebaseAuth
// import 'package:firebase_auth/firebase_auth.dart';
