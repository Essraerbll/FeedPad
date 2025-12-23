import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'feed_blog_screen.dart';
import 'feed_map_screen.dart';
import 'profile_screen.dart';
import 'messaging_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // FeedMap varsayılan (index 1)

  final List<Widget> _screens = [
    const FeedBlogScreen(),
    const FeedMapScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    'Feed Blog',
    'Feed Map',
    'Profile',
  ];

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
      // Dynamically determine actions based on current screen
    List<Widget> getAppBarActions() {
      if (_currentIndex == 0) {
        // FeedBlogScreen - Show message button
        return [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF7BA4D9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.message, color: Colors.white),
              tooltip: 'Messages',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MessagingScreen()),
                );
              },
            ),
          ),
        ];
      } else if (_currentIndex == 2) {
        // ProfileScreen - Show logout button
        return [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF7BA4D9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Sign Out',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFFF5F8FA),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Color(0xFF5A7FA1)),
                    ),
                    content: const Text(
                      'Are you sure you want to sign out?',
                      style: TextStyle(color: Colors.black87),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9DB8E8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF7BA4D9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _signOut();
                }
              },
            ),
          ),
        ];
      } else {
        // FeedMapScreen - No button
        return [];
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF9DB8E8),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.pets, size: 24, color: Colors.white),
            Text(
              _titles[_currentIndex],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 24),
          ],
        ),
        actions: getAppBarActions(),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFD4E5F7), // Açık pastel mavi nav
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: const Color(0xFFD4E5F7),
          selectedItemColor: const Color(0xFF5A7FA1),
          unselectedItemColor: const Color(0xFF9DB8E8),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
          ),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.article),
              label: 'Feed Blog',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on),
              label: 'Feed Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pets),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
