import 'package:flutter/material.dart';
import '../animations/route_animations.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback? onGetStarted;
  
  const WelcomeScreen({super.key, this.onGetStarted});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F1FA), // Yumuşak pastel mavi
      body: Stack(
        children: [
          // Background paw decorations - very soft
          Positioned(
            top: 60,
            right: 40,
            child: Icon(
              Icons.pets,
              size: 100,
              color: const Color(0xFFC5D9F1).withValues(alpha: 0.4),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 30,
            child: Icon(
              Icons.pets,
              size: 120,
              color: const Color(0xFFC5D9F1).withValues(alpha: 0.3),
            ),
          ),
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 80),

                        // Dog and cat illustration with paw decorations
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Left paw
                            Positioned(
                              left: 20,
                              top: 40,
                              child: Icon(
                                Icons.pets,
                                size: 40,
                                color: const Color(0xFFC5D9F1).withValues(alpha: 0.6),
                              ),
                            ),
                            // Right paw
                            Positioned(
                              right: 20,
                              top: 40,
                              child: Icon(
                                Icons.pets,
                                size: 40,
                                color: const Color(0xFFC5D9F1).withValues(alpha: 0.6),
                              ),
                            ),
                            // Left bottom paw
                            Positioned(
                              left: 40,
                              bottom: 20,
                              child: Icon(
                                Icons.pets,
                                size: 35,
                                color: const Color(0xFFC5D9F1).withValues(alpha: 0.5),
                              ),
                            ),
                            // Right bottom paw
                            Positioned(
                              right: 40,
                              bottom: 20,
                              child: Icon(
                                Icons.pets,
                                size: 35,
                                color: const Color(0xFFC5D9F1).withValues(alpha: 0.5),
                              ),
                            ),
                            // Main image
                            Image.asset(
                              'assets/images/logo.jpeg',
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),

                        const SizedBox(height: 60),

                        // Title - simple and clean
                        Text(
                          'Welcome to',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF6B7FA8),
                                fontWeight: FontWeight.w400,
                                fontSize: 18,
                              ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'FeedPad',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: const Color(0xFF5A7FA1),
                                fontWeight: FontWeight.bold,
                                fontSize: 48,
                              ),
                        ),

                        const SizedBox(height: 100),

                        // GET STARTED button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              if (widget.onGetStarted != null) {
                                widget.onGetStarted!();
                              } else {
                                Navigator.of(context).pushReplacement(
                                  FadeRoute(page: const LoginScreen()),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9DB8E8), // Çok açık pastel mavi
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                            ),
                            child: Text(
                              'GET STARTED',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}