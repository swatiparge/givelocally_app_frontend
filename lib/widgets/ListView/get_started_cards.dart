// lib/widgets/home/get_started_cards.dart
import 'package:flutter/material.dart';
import '../../screens/donation/blood_request_screen.dart';
import '../donation/category_selection_modal.dart'; // Ensure this path matches your file structure

class GetStartedCards extends StatelessWidget {
  const GetStartedCards({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildCard(
            context,
            "Donate",
            "Give an item",
            Colors.green.shade50,
            Colors.green.shade700,
            Icons.volunteer_activism,
                () => _showCategorySelection(context),
          ),
          _buildCard(
            context,
            "Request",
            "Items & Blood",
            Colors.red.shade50,
            Colors.red.shade700,
            Icons.front_hand_outlined,
                () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BloodRequestScreen()),
            ),
          ),
          _buildCard(
            context,
            "Community",
            "Connect locally",
            Colors.blue.shade50,
            Colors.blue.shade700,
            Icons.groups_outlined,
                () {
              // Future: Community logic
            },
          ),
        ],
      ),
    );
  }

  void _showCategorySelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CategorySelectionModal(),
    );
  }

  Widget _buildCard(
      BuildContext context,
      String title,
      String sub,
      Color bg,
      Color accent,
      IconData icon,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 16),
            ),
            Text(
              sub,
              style: TextStyle(color: accent.withOpacity(0.7), fontSize: 11),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}