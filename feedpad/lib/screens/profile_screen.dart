import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    final scheme = Theme.of(context).colorScheme;
    final background = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Title
            Text(
              'My Profile',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF5A7FA1),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Decorative header with cat and paw icons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF9DB8E8), const Color(0xFF7BA4D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // paw decorations
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Icon(Icons.pets, size: 28, color: Colors.white.withOpacity(0.15)),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 8,
                      child: Icon(Icons.pets, size: 40, color: Colors.white.withOpacity(0.12)),
                    ),
                    // center cat avatar
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.pets, size: 46, color: const Color(0xFF5A7FA1)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentUser?.name ?? 'Pet Owner',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentUser?.username ?? '@user',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            // Info card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email', style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 6),
                      Text(
                        currentUser?.email ?? 'Not available',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Text('Username', style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 6),
                      Text(
                        currentUser?.username ?? 'Not available',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

