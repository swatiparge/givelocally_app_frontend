import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PickupCodeScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;

  const PickupCodeScreen({super.key, required this.transaction});

  @override
  State<PickupCodeScreen> createState() => _PickupCodeScreenState();
}

class _PickupCodeScreenState extends State<PickupCodeScreen> {
  late Map<String, dynamic> _data;
  bool _isLoadingDonor = false;
  String? _donorPhone;
  String? _donorRating = "4.8";

  @override
  void initState() {
    super.initState();
    _data = widget.transaction;
    _fetchDonorDetails();
  }

  Future<void> _fetchDonorDetails() async {
    final donorId = _data['donorId'];
    if (donorId == null) return;

    setState(() => _isLoadingDonor = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(donorId).get();
      if (doc.exists && mounted) {
        final donorData = doc.data();
        setState(() {
          _donorPhone = donorData?['phone'];
          // You could also fetch rating here if it exists in the user doc
        });
      }
    } catch (e) {
      debugPrint("Error fetching donor details: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDonor = false);
    }
  }

  String _getTimeRemaining() {
    final expiresAt = _data['pickup_code_expires'];
    if (expiresAt == null) return "23h 59m";
    
    DateTime expiry;
    if (expiresAt is Timestamp) {
      expiry = expiresAt.toDate();
    } else if (expiresAt is String) {
      expiry = DateTime.parse(expiresAt);
    } else {
      return "23h 59m";
    }

    final diff = expiry.difference(DateTime.now());
    if (diff.isNegative) return "Expired";
    
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return "${hours}h ${minutes}m";
  }

  @override
  Widget build(BuildContext context) {
    final title = _data['donationTitle'] ?? _data['title'] ?? "Item";
    final donorName = _data['donorName'] ?? "Donor";
    final pickupCode = _data['pickup_code']?.toString() ?? "0000";
    final donorPhoto = _data['donorPhotoUrl'] ?? "";
    final address = _data['pickupAddress'] ?? _data['address'] ?? "Address details in chat";
    final imageUrl = _data['donationImage'] ?? _data['image'] ?? "";
    final category = _data['category'] ?? "Item";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Pickup Confirmed",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Payment Success Badge
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Color(0xFF4CAF50), size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text("Payment Successful h", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("You can now pick up your item", style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Pickup Code Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F1F1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  const Text("YOUR PICKUP CODE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  Text(
                    pickupCode.split('').join(' '),
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 8),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Color(0xFFE65100)),
                        const SizedBox(width: 6),
                        Text("Valid for: ${_getTimeRemaining()}", style: const TextStyle(color: Color(0xFFE65100), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: pickupCode));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied to clipboard")));
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text("Copy Code"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade200),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Simple share text
                            final text = "My GiveLocally Pickup Code for $title is: $pickupCode. Address: $address";
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Details copied to share")));
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text("Share Code"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade200),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Donor Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F1F1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE3F2FD),
                        backgroundImage: donorPhoto.isNotEmpty ? NetworkImage(donorPhoto) : null,
                        child: donorPhoto.isEmpty ? const Icon(Icons.person, color: Colors.blue) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(donorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Row(
                              children: [
                                const Text("Donor", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(width: 4),
                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 2),
                                Text(_donorRating ?? "4.8", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_donorPhone != null)
                        IconButton(
                          onPressed: () {
                            // ignore: deprecated_member_use
                            // launchUrl(Uri.parse("tel:$_donorPhone"));
                          },
                          icon: const Icon(Icons.phone, color: Colors.green),
                          style: IconButton.styleFrom(backgroundColor: const Color(0xFFE8F5E9)),
                        ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFF1F1F1)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place, color: Colors.grey, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Pickup Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(address, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              child: const Row(
                                children: [
                                  Text("GET DIRECTIONS", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                  SizedBox(width: 4),
                                  Icon(Icons.north_east, color: Colors.green, size: 14),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Item Details
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("ITEM DETAILS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F1F1)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl.isNotEmpty && imageUrl.startsWith('http')
                      ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                      : Container(width: 60, height: 60, color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text("$category • Reserved", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Bottom Done Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
