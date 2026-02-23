import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:razorpay_auth_capture/razorpay_auth_capture.dart';
import '../../services/auth_service.dart';

class ReserveItemScreen extends StatefulWidget {
  final Map<String, dynamic> donation;

  const ReserveItemScreen({super.key, required this.donation});

  @override
  State<ReserveItemScreen> createState() => _ReserveItemScreenState();
}

class _ReserveItemScreenState extends State<ReserveItemScreen> {
  late Razorpay _razorpay;
  late PaymentService _paymentService;
  bool _isLoading = false;

  final Color primaryGreen = const Color(0xFF66BB6A);
  final Color backgroundGrey = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _paymentService = PaymentService(const RazorpayConfig(
      keyId: 'rzp_test_SIILHau3fDK8ZR', // Replace with real key
      amount: 900, // ₹9.00 in paise
      merchantName: 'GiveLocally',
    ));
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
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.userModel;

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
            'description': 'Platform Fee',
            'prefill': {'contact': user.phone, 'email': user.email},
            'theme': {'color': '#66BB6A'}
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: primaryGreen, size: 64),
            const SizedBox(height: 16),
            const Text("Reservation Confirmed!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text("Your item has been reserved successfully.", textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: Text("OK", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
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
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Confirm Reservation', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
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
                  const Text("PAYMENT SUMMARY", style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  _buildPaymentSummaryCard(),
                  const SizedBox(height: 24),
                  _buildSecurityNote(),
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
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 90, height: 90, fit: BoxFit.cover)
                : Container(width: 90, height: 90, color: backgroundGrey, child: const Icon(Icons.image_outlined, color: Colors.grey)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text(category, style: TextStyle(color: primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1C1E))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: primaryGreen),
                    Text(" $distance km away", style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Platform Fee", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1C1E))),
                  SizedBox(height: 4),
                  Text("Secure reservation service", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Text("₹9", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryGreen)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info, color: primaryGreen, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "This small fee helps us keep the platform running and ensures your item is reserved securely.",
                  style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, color: primaryGreen, size: 16),
        const SizedBox(width: 8),
        const Text("Encrypted & Secure Payment", style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF1F1F1)))),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total to pay", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1C1E))),
                const Text("₹9", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: _isLoading ? null : _processPayment,
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.lock, size: 18),
                          SizedBox(width: 10),
                          Text("Pay & Reserve", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "By tapping Pay & Reserve, you agree to our Terms of Service.\nPayment will be processed via your default provider.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
