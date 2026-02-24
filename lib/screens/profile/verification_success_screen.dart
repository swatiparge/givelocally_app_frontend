import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VerificationSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> donation;

  const VerificationSuccessScreen({super.key, required this.donation});

  @override
  Widget build(BuildContext context) {
    final title = donation['title'] ?? "Item";
    final imageUrl = (donation['images'] as List?)?.first ?? "";
    final timestamp = donation['created_at'];
    String timeStr = "Just now";
    
    if (timestamp != null) {
      // Assuming it might be a Timestamp or DateTime depending on source
      final date = timestamp is DateTime ? timestamp : timestamp.toDate();
      timeStr = DateFormat('EEEE, h:mm a').format(date);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Verification Success",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Success Illustration
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(Icons.check, color: Color(0xFF4CAF50), size: 80),
                    // Decorative elements (simulating the confetti/stars from image)
                    Positioned(top: 10, right: 10, child: Icon(Icons.star, color: Colors.amber.shade300, size: 24)),
                    Positioned(bottom: 20, right: 0, child: Icon(Icons.thumb_up, color: Colors.green.shade200, size: 20)),
                    Positioned(top: 40, left: 0, child: Icon(Icons.celebration, color: Colors.blue.shade200, size: 24)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Pickup Completed!",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
              ),
              const SizedBox(height: 16),
              const Text(
                "Thank you for making a difference.\nYour generosity helps build a stronger community.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Color(0xFF6B7280), height: 1.5),
              ),
              const SizedBox(height: 40),
              
              // Karma Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  border: Border.all(color: const Color(0xFFF1F1F1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: Color(0xFF4CAF50), size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "+100 Karma",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1A1C1E)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Added to your profile",
                            style: TextStyle(color: Colors.green.shade700, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_upward, color: Color(0xFF4CAF50), size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Fee Released Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Color(0xFF3B82F6), size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Fee Released",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1C1E)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "The ₹50 promise fee has been successfully released back to the receiver.",
                            style: TextStyle(color: Colors.blue.shade800, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Donation Summary
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "DONATION SUMMARY",
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
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
                      child: imageUrl.isNotEmpty 
                        ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                        : Container(width: 60, height: 60, color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1C1E)),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // Bottom Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7CFF7C), // Design's neon green
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text(
                    "Back to My Donations",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
