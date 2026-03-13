import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_plugin/widgets/location_picker.dart';
import '../../config/default_location.dart';

/// A field widget that displays a map preview and opens a full location picker.
/// Used in donation forms for selecting pickup location.
class LocationPickerField extends StatefulWidget {
  final LatLng? selectedLocation;
  final String address;
  final Function(LatLng location, String address) onLocationSelected;

  const LocationPickerField({
    super.key,
    required this.selectedLocation,
    required this.address,
    required this.onLocationSelected,
  });

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  GoogleMapController? _previewController;

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LocationPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldLoc = oldWidget.selectedLocation;
    final newLoc = widget.selectedLocation;
    if (oldLoc == null || newLoc == null) return;

    final moved =
        oldLoc.latitude != newLoc.latitude ||
        oldLoc.longitude != newLoc.longitude;
    if (moved) {
      _previewController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: newLoc, zoom: 15),
        ),
      );
    }
  }

  Future<void> _openFullPicker(BuildContext context) async {
    final result = await Navigator.push<LocationResult>(
      context,
      MaterialPageRoute(
        builder: (context) => _DonationLocationPickerScreen(
          initialLocation: widget.selectedLocation,
        ),
      ),
    );

    if (!context.mounted || result == null) return;
    widget.onLocationSelected(
      result.location,
      result.address ?? 'Selected Location',
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedLocation = widget.selectedLocation;

    return InkWell(
      onTap: () => _openFullPicker(context),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              if (selectedLocation != null)
                IgnorePointer(
                  child: GoogleMap(
                    onMapCreated: (c) {
                      _previewController = c;
                      c.moveCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(target: selectedLocation, zoom: 15),
                        ),
                      );
                    },
                    initialCameraPosition: CameraPosition(
                      target: selectedLocation,
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId("selected"),
                        position: selectedLocation,
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.green.shade600,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Tap to select location on Map",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              Container(color: Colors.transparent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper screen that uses the shared LocationPicker with donation config.
class _DonationLocationPickerScreen extends StatelessWidget {
  final LatLng? initialLocation;

  const _DonationLocationPickerScreen({this.initialLocation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LocationPicker(
        initialPosition:
            initialLocation ?? const LatLng(kDefaultLat, kDefaultLng),
        config: LocationPickerConfig.donationPickup,
        onLocationSelected: (result) {
          Navigator.pop(context, result);
        },
      ),
    );
  }
}
