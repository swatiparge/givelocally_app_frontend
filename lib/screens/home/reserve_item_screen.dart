import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:razorpay_auth_capture/razorpay_auth_capture.dart';
import '../../providers/auth_provider.dart';

class ReserveItemScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> donation;

  const ReserveItemScreen({super.key, required this.donation});

  @override
  ConsumerState<ReserveItemScreen> createState() => _ReserveItemScreenState();
}

class _ReserveItemScreenState extends ConsumerState<ReserveItemScreen> {
  late Razorpay _razorpay;
  late PaymentService _paymentService;
  bool _isLoading = false;
  String _pickupMethod = 'self'; // 'self' or 'third_party'

  final Color primaryGreen = const Color(0xFF66BB6A);
  final Color backgroundGrey = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _paymentService = PaymentService(
      const RazorpayConfig(
        keyId: 'rzp_test_SIILHau3fDK8ZR',
        amount: 900,
        merchantName: 'GiveLocally',
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    setState(() => _isLoading = false);
    _showSuccessDialog();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isLoading = false);
    _showErrorDialog(response.message ?? 'Payment failed');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  Future<void> _processPayment() async {
    setState(() => _isLoading = true);
    final user = ref.read(userModelProvider).valueOrNull;

    if (user == null) {
      _showErrorDialog('Please log in to reserve items');
      setState(() => _isLoading = false);
      return;
    }

    final donationId = widget.donation['id'] ?? widget.donation['donationId'] ?? '';

    try {
      await _paymentService.startPayment(
        donationId: donationId,
        userPhone: user.phone,
        userEmail: user.email ?? 'user@givelocally.app',
        onSuccess: (orderId) {
          var options = {
            'key': 'rzp_test_SIILHau3fDK8ZR',
            'amount': 900,
            'name': 'GiveLocally',
            'order_id': orderId,
            'description': 'Reservation Fee',
            'prefill': {'contact': user.phone, 'email': user.email},
            'theme': {'color': '#66BB6A'},
          };
          _razorpay.open(options);
        },
        onError: (err) {
          setState(() => _isLoading = false);
          _showErrorDialog(err);
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Could not initiate payment');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: primaryGreen, size: 64),
            ),
            const SizedBox(height: 24),
            const Text(
              "Reservation Confirmed!",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF1A1C1E)),
            ),
            const SizedBox(height: 12),
            const Text(
              "Your item has been reserved successfully. You can now coordinate the pickup.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey, height: 1.5),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: const Text("Awesome!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.donation['title'] ?? 'Item';
    final distance = widget.donation['distance'] ?? '0.5';
    final category = (widget.donation['category'] ?? 'Others').toString().toUpperCase();
    final images = widget.donation['images'] as List?;
    final imageUrl = (images != null && images.isNotEmpty) ? images[0] : '';

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Confirm Reservation',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildItemCard(imageUrl, title, distance, category),
                  const SizedBox(height: 32),
                  const Text(
                    "PAYMENT SUMMARY",
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentSummaryCard(),
                  const SizedBox(height: 32),
                  const Text(
                    "PICKUP METHOD",
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 16),
                  _buildPickupOption(
                    id: 'self',
                    title: 'Self Pickup',
                    subtitle: 'Pay only ₹9 platform fee. You coordinate the pickup yourself.',
                    isSelected: _pickupMethod == 'self',
                  ),
                  const SizedBox(height: 12),
                  _buildPickupOption(
                    id: 'third_party',
                    title: 'Third-Party Delivery',
                    subtitle: 'Use services like Porter or Dunzo at your convenience. Extra delivery fees apply.',
                    isSelected: _pickupMethod == 'third_party',
                  ),
                ],
              ),
            ),
          ),
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildItemCard(String imageUrl, String title, dynamic distance, String category) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                : Container(
                    width: 80,
                    height: 80,
                    color: backgroundGrey,
                    child: const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(color: primaryGreen, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF1A1C1E)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: primaryGreen),
                    Text(
                      " $distance km away",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Platform Fee",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF1A1C1E)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Secure reservation service",
                    style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                "₹9",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.info, color: primaryGreen, size: 18),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "This small fee helps us keep the platform running and ensures your item is reserved securely.",
                  style: TextStyle(color: Colors.blueGrey, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickupOption({
    required String id,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _pickupMethod = id),
      borderRadius: BorderRadius.circular(32),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.black.withOpacity(0.05),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: primaryGreen.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))
            else
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1A1C1E)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primaryGreen : Colors.grey.shade300,
                  width: isSelected ? 7 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -10)),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total Payment",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                ),
                Text(
                  "₹9.00",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _isLoading ? null : _processPayment,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.shield_outlined, size: 20),
                          SizedBox(width: 12),
                          Text("Complete Reservation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
