import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../routes/app_router.dart';

class CategorySelectionModal extends StatelessWidget {
  const CategorySelectionModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "What are you giving?",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _categoryBtn(context, "Food", Icons.apple, Colors.orange),
              _categoryBtn(context, "Appliances", Icons.tv, Colors.blue),
              _categoryBtn(context, "Blood", Icons.bloodtype, Colors.red),
              _categoryBtn(context, "Stationery", Icons.book, Colors.purple),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _categoryBtn(BuildContext context, String title, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Close modal
        
        String route;
        switch (title.toLowerCase()) {
          case 'food':
            route = AppRouter.postFood;
            break;
          case 'appliances':
            route = AppRouter.postAppliances;
            break;
          case 'blood':
            route = AppRouter.postBlood;
            break;
          case 'stationery':
            route = AppRouter.postStationery;
            break;
          default:
            route = AppRouter.home;
        }
        
        context.push(route);
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}