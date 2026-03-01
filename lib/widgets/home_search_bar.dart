import 'package:flutter/material.dart';

class HomeSearchBar extends StatefulWidget {
  final VoidCallback onFilterTap;
  final Function(String) onSearchChanged;

  const HomeSearchBar({
    super.key,
    required this.onFilterTap,
    required this.onSearchChanged,
  });

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onClear() {
    _controller.clear();
    widget.onSearchChanged("");
    FocusScope.of(context).unfocus(); // Clear focus to return to home screen
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        controller: _controller,
        onChanged: widget.onSearchChanged,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        textInputAction: TextInputAction.search,
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
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20),
                  onPressed: _onClear,
                ),
              IconButton(
                icon: Icon(
                  Icons.tune,
                  color: Colors.grey.shade600,
                ),
                onPressed: widget.onFilterTap,
              ),
              const SizedBox(width: 4),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
