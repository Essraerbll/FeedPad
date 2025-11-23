import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // E-posta ile kayıt ol
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    String? username,
    String? location,
    required String userType,
  }) async {
    try {
      // Kullanıcı adı benzersizliğini kontrol et (eğer verilmişse)
      if (username != null && username.isNotEmpty) {
        final usernameExists = await _checkUsernameExists(username);
        if (usernameExists) {
          return 'Bu kullanıcı adı zaten kullanılıyor.';
        }
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      
      // Kullanıcı bilgilerini Firestore'a kaydet
      if (user != null) {
        // Firebase Auth profil güncelleme (displayName)
        await user.updateDisplayName(name);
        
        // Firestore'a detaylı kullanıcı bilgilerini kaydet
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'name': name,
          'username': username ?? '',
          'location': location ?? '',
          'userType': userType,
          'photoURL': '',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });

        // Eğer username varsa, ayrı bir koleksiyonda sakla (hızlı arama için)
        if (username != null && username.isNotEmpty) {
          await _firestore.collection('usernames').doc(username.toLowerCase()).set({
            'uid': user.uid,
            'username': username,
          });
        }
      }

      notifyListeners();
      return null; // Başarılı
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'Şifre çok zayıf.';
        case 'email-already-in-use':
          return 'Bu e-posta adresi zaten kullanımda.';
        case 'invalid-email':
          return 'Geçersiz e-posta adresi.';
        default:
          return 'Bir hata oluştu: ${e.message}';
      }
    } catch (e) {
      return 'Beklenmeyen bir hata oluştu: $e';
    }
  }

  // Kullanıcı adının benzersiz olup olmadığını kontrol et
  Future<bool> _checkUsernameExists(String username) async {
    try {
      final doc = await _firestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Kullanıcı bilgilerini getir
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Kullanıcı profilini güncelle
  Future<String?> updateUserProfile({
    required String uid,
    String? name,
    String? location,
    String? photoURL,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (location != null) updates['location'] = location;
      if (photoURL != null) updates['photoURL'] = photoURL;

      await _firestore.collection('users').doc(uid).update(updates);
      
      // Firebase Auth displayName güncelle
      if (name != null && currentUser != null) {
        await currentUser!.updateDisplayName(name);
      }

      notifyListeners();
      return null; // Başarılı
    } catch (e) {
      return 'Profil güncellenemedi: $e';
    }
  }

  // E-posta ile giriş yap
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return null; // Başarılı
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Kullanıcı bulunamadı.';
        case 'wrong-password':
          return 'Hatalı şifre.';
        case 'invalid-email':
          return 'Geçersiz e-posta adresi.';
        case 'user-disabled':
          return 'Bu hesap devre dışı bırakılmış.';
        default:
          return 'Giriş yapılamadı: ${e.message}';
      }
    } catch (e) {
      return 'Beklenmeyen bir hata oluştu.';
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  // Şifre sıfırlama e-postası gönder
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Başarılı
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          return 'Geçersiz e-posta adresi.';
        case 'user-not-found':
          return 'Kullanıcı bulunamadı.';
        default:
          return 'Bir hata oluştu: ${e.message}';
      }
    } catch (e) {
      return 'Beklenmeyen bir hata oluştu.';
    }
  }
}

