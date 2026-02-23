import 'package:flutter/material.dart';
import '../models/donation.dart';

/// Detail screen for a donation item
class DonationDetailScreen extends StatelessWidget {
  final Donation donation;

  const DonationDetailScreen({super.key, required this.donation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(donation.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category badge
            Chip(
              label: Text(
                donation.category.toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: _getCategoryColor(donation.category),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              donation.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),

            // Donor info
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16),
                const SizedBox(width: 4),
                Text('Donor: ${donation.donorName}'),
              ],
            ),
            const SizedBox(height: 4),

            // Condition
            Row(
              children: [
                const Icon(Icons.star_outline, size: 16),
                const SizedBox(width: 4),
                Text('Condition: ${donation.condition}'),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Description',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(donation.description),
            const SizedBox(height: 16),

            // Location
            Text(
              'Location',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Latitude: ${donation.latitude.toStringAsFixed(4)}'),
            Text('Longitude: ${donation.longitude.toStringAsFixed(4)}'),
            const SizedBox(height: 16),

            // Posted time
            Text(
              'Posted: ${_formatTime(donation.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const Spacer(),

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request sent to donor!')),
                  );
                },
                icon: const Icon(Icons.message),
                label: const Text('Contact Donor'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'food':
        return Colors.green;
      case 'appliances':
        return Colors.blue;
      case 'blood':
        return Colors.red;
      case 'stationery':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }
}
