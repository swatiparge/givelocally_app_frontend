import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// Pickup Code Display Screen
/// Shows 4-digit pickup code after successful payment
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
  DateTime? _expiryTime;
  Duration _timeRemaining = Duration.zero;
  bool _isExpired = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _data = widget.transaction;
    _fetchDonorDetails();
    _fetchTransactionFromFirestore();
  }

  /// Fetch fresh transaction data to ensure we have the correct pickup_code_expires
  Future<void> _fetchTransactionFromFirestore() async {
    final donationId = _data['donationId'];
    if (donationId == null) return;

    try {
      final transactionSnapshots = await FirebaseFirestore.instance
          .collection('transactions')
          .where('donationId', isEqualTo: donationId)
          .where('payment_status', whereIn: ['authorized', 'captured'])
          .limit(1)
          .get();

      if (transactionSnapshots.docs.isNotEmpty && mounted) {
        final transactionData = transactionSnapshots.docs.first.data();
        setState(() {
          // Merge fresh transaction data - this ensures pickup_code_expires is correct
          _data = {
            ..._data,
            ...transactionData,
            // Explicitly ensure we use pickup_code_expires from transaction
            'pickup_code_expires': transactionData['pickup_code_expires'],
          };
        });
        _calculateTimeRemaining();
        _startTimer();
      }
    } catch (e) {
      debugPrint('Error fetching transaction data: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateTimeRemaining() {
    // CRITICAL: Use pickup_code_expires from transactions collection (24h expiry)
    // NOT expires_at from donations collection (30 days)
    dynamic expiresAt = _data['pickup_code_expires'];

    debugPrint('[PickupCodeScreen] Reading expiry fields:');
    debugPrint(' - pickup_code_expires: ${_data['pickup_code_expires']}');
    debugPrint(' - expires_at: ${_data['expires_at']}');

    // Fallback: Check authorization_expires (also 24h from transactions)
    // DO NOT use expires_at from donations (30 days)
    if (expiresAt == null) {
      expiresAt = _data['authorization_expires'];
      if (expiresAt != null) {
        debugPrint('[PickupCodeScreen] Using authorization_expires fallback');
      }
    }

    if (expiresAt == null) {
      debugPrint(
          '[PickupCodeScreen] No valid expiry field found, defaulting to 24h');
      _timeRemaining = const Duration(hours: 23, minutes: 59);
      return;
    }

    if (expiresAt == null) {
      debugPrint('[PickupCodeScreen] No expiry field found, defaulting to 24h');
      _timeRemaining = const Duration(hours: 23, minutes: 59);
      return;
    }

    DateTime expiry;
    if (expiresAt is Timestamp) {
      expiry = expiresAt.toDate();
    } else if (expiresAt is String) {
      expiry = DateTime.parse(expiresAt);
    } else {
      debugPrint('[PickupCodeScreen] Invalid expiry format: $expiresAt');
      _timeRemaining = const Duration(hours: 23, minutes: 59);
      return;
    }

    final now = DateTime.now();
    _expiryTime = expiry;

    debugPrint('[PickupCodeScreen] Expiry calculated:');
    debugPrint('  - Expiry date: $expiry');
    debugPrint('  - Time remaining: ${expiry.difference(now)}');

    if (now.isAfter(expiry)) {
      _timeRemaining = Duration.zero;
      _isExpired = true;
      debugPrint('[PickupCodeScreen] Code EXPIRED');
    } else {
      _timeRemaining = expiry.difference(now);
      _isExpired = false;
      debugPrint(
          '[PickupCodeScreen] Code valid, hours: ${_timeRemaining.inHours}');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_expiryTime == null) return;

      final now = DateTime.now();
      if (now.isAfter(_expiryTime!)) {
        setState(() {
          _timeRemaining = Duration.zero;
          _isExpired = true;
        });
        timer.cancel();
        _showExpiredDialog();
      } else {
        setState(() {
          _timeRemaining = _expiryTime!.difference(now);
        });
      }
    });
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Code Expired'),
        content: const Text(
            'The pickup code has expired. The item will be relisted and the promise fee will be forfeited.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getTimeRemaining() {
    if (_isExpired) return "Expired";

    final hours = _timeRemaining.inHours;
    final minutes = _timeRemaining.inMinutes.remainder(60);
    final seconds = _timeRemaining.inSeconds.remainder(60);

    if (hours > 0) {
      return "${hours}h ${minutes}m ${seconds}s";
    } else if (minutes > 0) {
      return "${minutes}m ${seconds}s";
    } else {
      return "${seconds}s";
    }
  }

  Color _getExpiryColor() {
    if (_isExpired) return const Color(0xFFE53935);
    final hours = _timeRemaining.inHours;
    if (hours < 1) return const Color(0xFFE53935); // Less than 1 hour
    if (hours < 6) return const Color(0xFFFF9800); // Less than 6 hours
    return const Color(0xFF4CAF50); // More than 6 hours
  }

  Future<void> _fetchDonorDetails() async {
    final donorId = _data['donorId'];
    if (donorId == null) return;

    setState(() => _isLoadingDonor = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(donorId)
          .get();
      if (doc.exists && mounted) {
        final donorData = doc.data();
        setState(() {
          _donorPhone = donorData?['phone'];
          // Rating could be fetched if available in user document
        });
      }
    } catch (e) {
      debugPrint("Error fetching donor details: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDonor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _data['donationTitle'] ?? _data['title'] ?? "Item";
    final donorName = _data['donorName'] ?? "Donor";
    final pickupCode = _data['pickup_code']?.toString() ?? "0000";
    final donorPhoto = _data['donorPhotoUrl'] ?? "";
    final address =
        _data['pickupAddress'] ?? _data['address'] ?? "Address details in chat";
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
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
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
                    decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                    child: const Icon(Icons.check,
                        color: Color(0xFF4CAF50), size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text("Payment Successful",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("You can now pick up your item",
                      style: TextStyle(color: Colors.grey.shade600)),
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
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  const Text("YOUR PICKUP CODE",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1)),
                  const SizedBox(height: 16),
                  Text(
                    pickupCode.split('').join(' '),
                    style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getExpiryColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getExpiryColor(), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: _getExpiryColor()),
                        const SizedBox(width: 6),
                        Text(
                          _isExpired
                              ? "Expired"
                              : "Valid for: ${_getTimeRemaining()}",
                          style: TextStyle(
                            color: _getExpiryColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Code copied to clipboard")));
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text("Copy Code"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade200),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Simple share text
                            final text =
                                "My GiveLocally Pickup Code for $title is: $pickupCode. Address: $address";
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Details copied to share")));
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text("Share Code"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade200),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
                        backgroundImage: donorPhoto.isNotEmpty
                            ? NetworkImage(donorPhoto)
                            : null,
                        child: donorPhoto.isEmpty
                            ? const Icon(Icons.person, color: Colors.blue)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(donorName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Row(
                              children: [
                                const Text("Donor",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                const SizedBox(width: 4),
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 12),
                                const SizedBox(width: 2),
                                Text(_donorRating ?? "4.8",
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
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
                          style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFE8F5E9)),
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
                            const Text("Pickup Address",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(address,
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    height: 1.4)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap),
                              child: const Row(
                                children: [
                                  Text("GET DIRECTIONS",
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  SizedBox(width: 4),
                                  Icon(Icons.north_east,
                                      color: Colors.green, size: 14),
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
              child: Text("ITEM DETAILS",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 0.5)),
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
                        ? Image.network(imageUrl,
                            width: 60, height: 60, fit: BoxFit.cover)
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.image, color: Colors.grey)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text("$category • Reserved",
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13)),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text("Done",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
