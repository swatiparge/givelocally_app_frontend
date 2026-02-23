import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../src/payment_service.dart';
import '../razorpay_auth_capture.dart';

/// Pickup Code Display Screen
/// WF-21: Shows 4-digit pickup code after successful payment
class PickupCodeScreen extends StatefulWidget {
  final String transactionId;

  const PickupCodeScreen({super.key, required this.transactionId});

  @override
  State<PickupCodeScreen> createState() => _PickupCodeScreenState();
}

class _PickupCodeScreenState extends State<PickupCodeScreen> {
  late final PaymentService _paymentService;
  String? _pickupCode;
  String? _donorName;
  String? _donorPhone;
  String? _address;
  DateTime? _expiresAt;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _paymentService = RazorpayAuthCapture().createPaymentService();
    _loadTransactionData();
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _loadTransactionData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.transactionId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
          _pickupCode = data['pickup_code'];
          _expiresAt = (data['pickup_code_expires'] as Timestamp).toDate();
        });

        // Load donor info separately (security)
        final donorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['donorId'])
            .get();

        if (donorDoc.exists) {
          final donorData = donorDoc.data() as Map<String, dynamic>;
          setState(() {
            _donorName = donorData['name'];
            _donorPhone = donorData['phone'];
          });
        }

        // Load donation address
        final donationDoc = await FirebaseFirestore.instance
            .collection('donations')
            .doc(data['donationId'])
            .get();

        if (donationDoc.exists) {
          final donationData = donationDoc.data() as Map<String, dynamic>;
          setState(() {
            _address = donationData['address'];
          });
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading transaction: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getTimeRemaining() {
    if (_expiresAt == null) return '';

    final now = DateTime.now();
    final difference = _expiresAt!.difference(now);

    if (difference.isNegative) return 'Expired';

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    return '${hours}h ${minutes}m';
  }

  void _copyCode() {
    // TODO: Implement clipboard copy
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup Code'),
        actions: [
          if (_pickupCode != null)
            IconButton(icon: const Icon(Icons.share), onPressed: _copyCode),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pickupCode == null
          ? const Center(child: Text('Error loading pickup code'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Pickup Code',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _pickupCode!,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 8,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Valid for: ${_getTimeRemaining()}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Donor Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_donorName != null)
                    _InfoRow(
                      icon: Icons.person,
                      label: 'Name',
                      value: _donorName!,
                    ),
                  if (_donorPhone != null)
                    _InfoRow(
                      icon: Icons.phone,
                      label: 'Phone',
                      value: _donorPhone!,
                    ),
                  if (_address != null)
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Address',
                      value: _address!,
                    ),
                  const SizedBox(height: 32),
                  const Text(
                    'Show this code to the donor when you pick up the item.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}
