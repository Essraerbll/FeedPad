import 'package:flutter/material.dart';

class FeedBlogScreen extends StatelessWidget {
  const FeedBlogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F1FA), // Pastel mavi
      body: Stack(
        children: [
          // Background paw decorations - very light
          Positioned(
            top: 20,
            right: 20,
            child: Icon(Icons.pets, size: 80, color: const Color(0xFFC5D9F1).withOpacity(0.2)),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Icon(Icons.pets, size: 100, color: const Color(0xFFC5D9F1).withOpacity(0.15)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pets, size: 60, color: const Color(0xFF9DB8E8)),
                const SizedBox(height: 16),
                Text(
                  'FeedBlog',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFF5A7FA1),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
