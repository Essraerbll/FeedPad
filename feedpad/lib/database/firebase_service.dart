import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Uygulamanın Firebase ile ilgili işlemlerini yöneten yardımcı sınıf.
class FirebaseService {
  const FirebaseService._();

  /// Firebase'i uygulama başlarken başlatır.
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      developer.log('Firebase başarıyla başlatıldı.');
    } catch (e, stackTrace) {
      developer.log(
        'HATA: Firebase başlatılamadı: $e',
        stackTrace: stackTrace,
      );
    }
  }

  /// Kullanıcının oturum durumunu izleyen akış.
  static Stream<User?> authStateChanges() {
    return FirebaseAuth.instance.authStateChanges();
  }
}

