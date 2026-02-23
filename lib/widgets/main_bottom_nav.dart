// lib/widgets/common/main_bottom_nav.dart

import 'package:flutter/material.dart';

class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      elevation: 10,
      shape: const CircularNotchedRectangle(),
      // Creates the notch for the FAB
      notchMargin: 8.0,
      // Space between FAB and the bar
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, Icons.home, "Home", 0),
            _buildNavItem(Icons.groups_outlined, Icons.groups, "Community", 1),
            const SizedBox(width: 40), // Space for the center FAB
            _buildNavItem(
                Icons.chat_bubble_outline, Icons.chat_bubble, "Chat", 2),
            _buildNavItem(Icons.person_outline, Icons.person, "Profile", 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData inactiveIcon, IconData activeIcon, String label,
      int index) {
    bool isSelected = currentIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? activeIcon : inactiveIcon,
            color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
            size: 26,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}