import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'verification_success_screen.dart';

class CompletePickupScreen extends StatefulWidget {
  final Map<String, dynamic> donation;

  const CompletePickupScreen({super.key, required this.donation});

  @override
  State<CompletePickupScreen> createState() => _CompletePickupScreenState();
}

class _CompletePickupScreenState extends State<CompletePickupScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {}); // Refresh to update box borders
  }

  Future<void> _verifyAndComplete() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the 4-digit code")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final donationId = widget.donation['id'];
      if (donationId == null) throw "Donation ID not found";

      debugPrint("Completing pickup for donation: $donationId with code: $code");

      // Use the region specified in your environment/other services
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('verifyPickupCode');

      final result = await callable.call({
        'donationId': donationId,
        'pickupCode': code,
      });

      // Based on typical response structure in your project
      final data = result.data;
      bool success = false;
      String? message;

      if (data is Map) {
        success = data['success'] == true;
        message = data['message'];
      }

      if (success) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationSuccessScreen(donation: widget.donation),
            ),
          );
        }
      } else {
        throw message ?? "Invalid verification code. Please try again.";
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint("FirebaseFunctionsException: ${e.code} - ${e.message}");
      if (mounted) {
        String errorMsg = e.message ?? "Verification failed";
        if (e.code == 'invalid-argument') {
          errorMsg = "Invalid pickup code. Please check with the receiver.";
        } else if (e.code == 'not-found') {
          errorMsg = "Donation record not found.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Verification Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.donation['title'] ?? "Item";
    final area = widget.donation['area'] ?? widget.donation['location_name'] ?? "Unknown Location";
    final images = widget.donation['images'] as List?;
    final imageUrl = (images != null && images.isNotEmpty) ? images.first : "";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Complete Pickup",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Item Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl.isNotEmpty 
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
                        Row(
                          children: [
                            const Icon(Icons.place, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text("Pickup from $area", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_open, color: Color(0xFF4CAF50), size: 32),
            ),
            const SizedBox(height: 24),
            
            const Text(
              "Ask the receiver:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "\"What is your pickup code?\"",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            
            // OTP Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => _buildOtpBox(index)),
            ),
            const SizedBox(height: 100),
            
            // Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7CFF7C), // Match design's neon green
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text("VERIFY & COMPLETE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {},
              child: const Text(
                "Having trouble with the code?",
                style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    bool hasValue = _controllers[index].text.isNotEmpty;
    return Container(
      width: 64,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasValue ? const Color(0xFF4CAF50) : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (val) => _onChanged(val, index),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
      ),
    );
  }
}
