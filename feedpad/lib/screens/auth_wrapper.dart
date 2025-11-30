import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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

    // Kullanıcı giriş yapmışsa ana ekrana yönlendir
    if (authService.isAuthenticated) {
      return const MainScreen();
    }

    // Kullanıcı giriş yapmamışsa login ekranına yönlendir
    return const LoginScreen();
  }
}
