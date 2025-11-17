import 'package:flutter/material.dart';
import 'auth/auth_screen.dart';
import 'database/firebase_service.dart';
import 'main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseService.initializeFirebase();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Auth durumunu kontrol eden merkezi widget
  Widget _buildAuthGate() {
    return StreamBuilder(
      stream: FirebaseService.authStateChanges(),
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
