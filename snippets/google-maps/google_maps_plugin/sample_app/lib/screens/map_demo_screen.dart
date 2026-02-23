import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_plugin/google_maps_plugin.dart';
import '../models/donation.dart';
import '../data/mock_donations.dart';
import 'donation_detail_screen.dart';

/// Demo screen showing UnifiedMapView with mock data
class MapDemoScreen extends StatefulWidget {
  const MapDemoScreen({super.key});

  @override
  State<MapDemoScreen> createState() => _MapDemoScreenState();
}

class _MapDemoScreenState extends State<MapDemoScreen> {
  Map<String, BitmapDescriptor> _categoryIcons = {};
  bool _iconsLoaded = false;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    // In a real app, load actual icon assets
    // For demo, we'll use default markers with different hues
    final foodIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueGreen,
    );
    final appliancesIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueBlue,
    );
    final bloodIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueRed,
    );
    final stationeryIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueOrange,
    );
    final otherIcon = BitmapDescriptor.defaultMarker;

    setState(() {
      _categoryIcons = {
        'food': foodIcon,
        'appliances': appliancesIcon,
        'blood': bloodIcon,
        'stationery': stationeryIcon,
        'other': otherIcon,
      };
      _iconsLoaded = true;
    });
  }

  Future<List<MapMarkerItem>> _fetchItems(LatLng center, double radius) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Get mock data
    final donations = _selectedCategory != null
        ? MockData.getDonationsByCategory(_selectedCategory!)
        : MockData.getSampleDonations();

    // Filter by distance (simplified - in real app, use backend)
    final filtered = donations.where((donation) {
      final distance = _calculateDistance(
        center.latitude,
        center.longitude,
        donation.latitude,
        donation.longitude,
      );
      return distance <= radius;
    }).toList();

    return filtered;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Simple distance calculation in km
    const double earthRadius = 6371;
    final double dLat = (lat2 - lat1) * (3.14159265359 / 180);
    final double dLon = (lon2 - lon1) * (3.14159265359 / 180);
    final double a =
        (dLat / 2) * (dLat / 2) +
        (dLon / 2) *
            (dLon / 2) *
            (1 + (3.14159265359 / 180) * (1 + (3.14159265359 / 180)));
    final double c = 2 * (dLat / 2).abs() + (dLon / 2).abs();
    return earthRadius * c;
  }

  void _onItemTap(MapMarkerItem item) {
    final donation = item as Donation;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DonationDetailScreen(donation: donation),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter by Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedCategory == null,
                    onSelected: (_) {
                      setState(() => _selectedCategory = null);
                      Navigator.pop(context);
                    },
                  ),
                  FilterChip(
                    label: const Text('Food'),
                    selected: _selectedCategory == 'food',
                    onSelected: (_) {
                      setState(() => _selectedCategory = 'food');
                      Navigator.pop(context);
                    },
                  ),
                  FilterChip(
                    label: const Text('Appliances'),
                    selected: _selectedCategory == 'appliances',
                    onSelected: (_) {
                      setState(() => _selectedCategory = 'appliances');
                      Navigator.pop(context);
                    },
                  ),
                  FilterChip(
                    label: const Text('Blood'),
                    selected: _selectedCategory == 'blood',
                    onSelected: (_) {
                      setState(() => _selectedCategory = 'blood');
                      Navigator.pop(context);
                    },
                  ),
                  FilterChip(
                    label: const Text('Stationery'),
                    selected: _selectedCategory == 'stationery',
                    onSelected: (_) {
                      setState(() => _selectedCategory = 'stationery');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _iconsLoaded
          ? UnifiedMapView(
              onFetchItems: _fetchItems,
              categoryIcons: _categoryIcons,
              onItemTap: _onItemTap,
              initialPosition: const LatLng(17.3850, 78.4867), // Hyderabad
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
