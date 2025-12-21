import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showWelcome = true; // İlk kez açılışta welcome göster

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Loading durumu
    if (authService.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // İlk kez açılışta welcome ekranını göster (kalıcı - sadece buton ile geç)
    if (_showWelcome && !authService.isAuthenticated) {
      return WelcomeScreen(
        onGetStarted: () {
          setState(() => _showWelcome = false);
        },
      );
    }

    // Kullanıcı giriş yapmışsa ana ekrana yönlendir
    if (authService.isAuthenticated) {
      return const MainScreen();
    }

    // Kullanıcı giriş yapmamışsa login ekranına yönlendir
    return const LoginScreen();
  }
}
