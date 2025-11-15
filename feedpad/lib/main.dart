import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'mapping/map_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/auth_screen.dart';

void main() async {
  // 1. Flutter widget'larının kullanıma hazır olduğundan emin ol
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // 2. Firebase initialize'ı bekle
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log('Firebase başarıyla başlatıldı.');
  } catch (e) {
    developer.log('HATA: Firebase başlatılamadı: $e');
    // Eğer burada bir hata alırsak, uygulama Firebase hizmetlerini kullanamaz
  }
  
  // 3. Uygulamayı çalıştır
  runApp(const MyApp()); 
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FeedPad Harita',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, userSnapshot) {
          if (userSnapshot.hasData) {
            return const MapScreen(); // Kullanıcı oturum açmışsa ana ekrana yönlendir
          }
          return const AuthScreen(); // Kullanıcı oturum açmamışsa giriş ekranına yönlendir
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
