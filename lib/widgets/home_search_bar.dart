// lib/widgets/home/home_search_bar.dart
import 'package:flutter/material.dart';

class HomeSearchBar extends StatelessWidget {
  final VoidCallback onFilterTap;
  final Function(String) onSearchChanged;

  const HomeSearchBar({
    super.key,
    required this.onFilterTap,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Padding outside the search bar
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: "Search furniture, food, books...",
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey.shade400,
            size: 22,
          ),
          // Filter Icon on the right
          suffixIcon: Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                Icons.tune, // Matches the filter/settings icon in design
                color: Colors.grey.shade600,
              ),
              onPressed: onFilterTap,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}