import 'package:flutter/material.dart';

class CommunityComingSoonScreen extends StatelessWidget {
  const CommunityComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              const SizedBox(height: 30),
              // AI Generated Style Image
              ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    'https://images.unsplash.com/photo-1511632765486-a01980e01a18?q=80&w=1000&auto=format&fit=crop',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[100],
                      child: const Icon(Icons.groups, size: 80, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
              
              // Headline
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    height: 1.1,
                  ),
                  children: [
                    TextSpan(text: 'Unlocking New\nPossibilities for '),
                    TextSpan(
                      text: 'Local\nImpact',
                      style: TextStyle(color: Color(0xFF66BB6A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Discover enhanced ways to give and grow together as we launch powerful new tools designed for your community.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blueGrey[600],
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
