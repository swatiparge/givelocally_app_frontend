// lib/widgets/ListView/urgent_blood_request_card.dart
import 'package:flutter/material.dart';
import '../../routes/app_router.dart';

class UrgentBloodRequestCard extends StatelessWidget {
  final Map<String, dynamic> donation;
  final bool isPostedByMe;

  const UrgentBloodRequestCard({
    super.key,
    required this.donation,
    this.isPostedByMe = false,
  });

  String _getExpiryLabel(Map<String, dynamic>? pickupWindow) {
    if (pickupWindow == null || pickupWindow['end_date'] == null)
      return "Urgent";

    final endSeconds = pickupWindow['end_date']['_seconds'] as int;
    final endTime = DateTime.fromMillisecondsSinceEpoch(endSeconds * 1000);
    final now = DateTime.now();

    final difference = endTime.difference(now);

    if (difference.isNegative) return "Expired";
    if (difference.inHours > 0) return "Expires in ${difference.inHours}h";
    return "Expires in ${difference.inMinutes}m";
  }

  @override
  Widget build(BuildContext context) {
    // Mapping API data to local variables
    final bloodType =
        donation['blood_group'] ?? donation['blood_type'] ?? 'Unknown';
    final hospitalName = donation['hospital_name'] ?? 'Local Hospital';
    final urgency = donation['urgency'] ?? 'standard';
    final isCritical = urgency == 'critical';
    final distance =
        donation['distance'] ?? '0.5km'; // Usually calculated by geofire logic

    // Updated to use 'username' as requested, with fallbacks
    final userName = donation['username'] ?? donation['userName'] ?? donation['donorName'] ?? donation['name'] ?? "Donor";

    final pickupWindow = donation['pickup_window'] as Map<String, dynamic>?;

    String? imageUrl;
    final images = donation['images'];
    if (images is List && images.isNotEmpty && images.first is String) {
      imageUrl = images.first as String;
    } else if (images is String) {
      imageUrl = images;
    }

    final bool canShowImage =
        imageUrl != null &&
        imageUrl.startsWith('http') &&
        !imageUrl.toLowerCase().endsWith('.pdf');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical ? Colors.red.shade100 : Colors.blue.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canShowImage)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.black.withOpacity(0.04),
                    child: const Center(
                      child: Icon(Icons.bloodtype, color: Colors.redAccent),
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCritical
                      ? Colors.red.shade600
                      : Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isCritical ? "CRITICAL REQUEST" : "BLOOD REQUEST",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isPostedByMe) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "POSTED BY YOU",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: isCritical ? Colors.red.shade600 : Colors.blue.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                _getExpiryLabel(pickupWindow),
                style: TextStyle(
                  color: isCritical
                      ? Colors.red.shade600
                      : Colors.blue.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "$bloodType Blood Needed",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.local_hospital_outlined,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  "$hospitalName • $distance away",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isCritical
                    ? Colors.red.shade200
                    : Colors.blue.shade200,
                child: const Icon(Icons.person, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                isPostedByMe ? "Requested by You" : "Req. by $userName",
                style: const TextStyle(fontSize: 13),
              ),
              const Spacer(),
              if (!isPostedByMe)
                ElevatedButton(
                  onPressed: () {
                    // Navigate to WF-16: Donation Detail Screen
                    context.goToDonationDetail(donation);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCritical
                        ? Colors.red.shade600
                        : Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Donate"),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
