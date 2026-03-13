import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_plugin/widgets/location_picker.dart';
import '../../providers/auth_provider.dart';
import 'profile_setup_screen.dart';

/// Location confirmation screen for onboarding flow.
/// Uses the shared LocationPicker widget with onboarding configuration.
class LocationConfirmationScreen extends ConsumerStatefulWidget {
  final bool navigateToProfileSetup;

  const LocationConfirmationScreen({
    super.key,
    this.navigateToProfileSetup = true,
  });

  @override
  ConsumerState<LocationConfirmationScreen> createState() =>
      _LocationConfirmationScreenState();
}

class _LocationConfirmationScreenState
    extends ConsumerState<LocationConfirmationScreen> {
  bool _isLoading = false;

  Future<void> _onLocationSelected(LocationResult result) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final uid = authService.firebaseUser?.uid;

      if (uid == null) throw Exception("User not authenticated");

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'location': GeoPoint(
          result.location.latitude,
          result.location.longitude,
        ),
        'address': result.address ?? 'Selected Location',
        'area': result.area ?? 'Unknown Area',
        'location_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        if (widget.navigateToProfileSetup) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => const ProfileSetupScreen()),
          );
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("Error saving location: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to save location: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LocationPicker(
              onLocationSelected: _onLocationSelected,
              config: LocationPickerConfig.onboarding,
            ),
    );
  }
}
