import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/auth_screen.dart';
import 'main_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log('Firebase başarıyla başlatıldı.');
  } catch (e) {
    developer.log('HATA: Firebase başlatılamadı: $e');
  }
  
  runApp(const MyApp()); 
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Auth durumunu kontrol eden merkezi widget
  Widget _buildAuthGate() {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (userSnapshot.hasData) {
          // Oturum açmışsa MainScreen'e yönlendir
          return const MainScreen(); 
        }
        // Oturum açmamışsa Giriş ekranına yönlendir
        return const AuthScreen(); 
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FeedPad Harita',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // 'home' yerine '/' rotasını kullanıyoruz ve bu rotaya Auth kontrolünü veriyoruz.
      initialRoute: '/',
      routes: {
        // Ana rota ('/') her zaman Auth durumunu kontrol ederek doğru sayfaya yönlendirir.
        '/': (ctx) => _buildAuthGate(),
        // Bu rotalar eklenmeli, böylece Navigator.pushNamed çalışabilir
        '/auth': (ctx) => const AuthScreen(),
        '/main': (ctx) => const MainScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}