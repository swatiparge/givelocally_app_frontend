import 'package:flutter/material.dart';

class DonationSuccessView extends StatelessWidget {
  final VoidCallback onPostAnother;
  final VoidCallback onViewDonation;

  const DonationSuccessView({
    super.key,
    required this.onPostAnother,
    required this.onViewDonation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Top Close Button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 28, color: Colors.black),
                  onPressed: onPostAnother,
                ),
              ),
              const Spacer(),

              // Success Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),

              // Heading
              const Text(
                "Donation Posted\nSuccessfully!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),

              // Subheading
              const Text(
                "Your item is now visible to receivers nearby. We'll notify you as soon as someone expresses interest.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Serious Inquiries Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF5F5F5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4), // FIXED: Added Offset constructor
                    )
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Serious Inquiries Only",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Receivers will pay a promise fee to book this item, ensuring they show up for pickup.",
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const Spacer(),

              // Buttons
              ElevatedButton.icon(
                onPressed: onPostAnother,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text("Post Another"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF76E24E),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onViewDonation,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                child: const Text(
                  "View My Donation",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}