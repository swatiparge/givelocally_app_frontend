// lib/widgets/home/view_toggle.dart

import 'package:flutter/material.dart';

class ViewToggle extends StatelessWidget {
  final bool isListView;
  final Function(bool) onChanged;

  const ViewToggle({super.key, required this.isListView, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildBtn("List View", Icons.list, isListView),
          _buildBtn("Map View", Icons.map_outlined, !isListView),
        ],
      ),
    );
  }

  Widget _buildBtn(String label, IconData icon, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(label == "List View"),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isActive ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isActive ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isActive ? Colors.green : Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}