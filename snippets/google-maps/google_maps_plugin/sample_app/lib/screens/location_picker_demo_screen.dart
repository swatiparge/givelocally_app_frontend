import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_plugin/google_maps_plugin.dart';

/// Demo screen showing LocationPicker usage
class LocationPickerDemoScreen extends StatefulWidget {
  const LocationPickerDemoScreen({super.key});

  @override
  State<LocationPickerDemoScreen> createState() =>
      _LocationPickerDemoScreenState();
}

class _LocationPickerDemoScreenState extends State<LocationPickerDemoScreen> {
  LatLng? _selectedLocation;
  String? _selectedAddress;

  void _openLocationPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPicker(
          onLocationSelected: (LocationResult result) {
            setState(() {
              _selectedLocation = result.location;
              _selectedAddress = result.address ?? 'No address available';
            });
            Navigator.pop(context);

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location selected successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          },
          confirmButtonText: 'Use This Location',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Picker Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a location for your donation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to open the map and pick a location. '
              'Drag the map to move the pin to your desired location.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Selected location display
            if (_selectedLocation != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Selected Location',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Address:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        _selectedAddress!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Coordinates:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                        '${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Open picker button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openLocationPicker,
                icon: const Icon(Icons.map),
                label: Text(
                  _selectedLocation == null
                      ? 'Select Location'
                      : 'Change Location',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Clear button
            if (_selectedLocation != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedLocation = null;
                      _selectedAddress = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Selection'),
                ),
              ),

            const Spacer(),

            // Use case examples
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use Cases:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Set pickup location for donations'),
                  const Text('• Mark delivery addresses'),
                  const Text('• Find nearby stores or services'),
                  const Text('• Share locations with others'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
