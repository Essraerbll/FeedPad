import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  var _isLogin = true;
  var _userEmail = '';
  var _userUsername = '';
  var _userBio = '';
  var _userLocation = '';
  var _userPassword = '';

  void _trySubmit() async {
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus(); // Klavyeyi kapat

    if (isValid) {
      _formKey.currentState!.save();
      try {
        if (_isLogin) {
          // Giriş yap
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _userEmail,
            password: _userPassword,
          );
        } else {
          // Kayıt ol
          // NOT: Cloud Function (createUserProfile) otomatik olarak
          // Firestore'a profil belgesi oluşturacak. İstemci burada yazmaya gerek yok.
          final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _userEmail,
            password: _userPassword,
          );
          
          // Kullanıcı adını displayName olarak ayarla (Cloud Function bunu kullanır)
          await userCredential.user?.updateDisplayName(_userUsername);
          
          // İlgili bilgileri Firestore'a kaydet (Cloud Function tarafından yapılan temel profili güncellemeliyiz)
          // Kullanıcı bio ve location'ı sağladıysa, bunları Firestore'a yaz
          if (_userBio.isNotEmpty || _userLocation.isNotEmpty) {
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userCredential.user!.uid)
                  .update({
                'bio': _userBio,
                'location': _userLocation,
              });
            } catch (e) {
              developer.log('Bio/Location güncellemesi başarısız: $e');
            }
          }
          
          developer.log('Yeni kullanıcı kaydedildi: ${userCredential.user?.uid}');
          developer.log('Cloud Function otomatik olarak Firestore\'a profil belgesi yazacak.');
        }
      } on FirebaseAuthException catch (e) {
        String message = 'Bir hata oluştu, lütfen kontrol edin!';
        if (e.message != null) {
          message = e.message!;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } catch (e) {
        developer.log(e.toString());
      }
    }
  }

  void _resetPassword() async {
    if (_userEmail.isEmpty || !_userEmail.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lütfen geçerli bir e-posta adresi girin.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _userEmail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Şifre sıfırlama bağlantısı $_userEmail adresine gönderildi.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Şifre sıfırlama e-postası gönderilirken bir hata oluştu.';
      if (e.message != null) {
        message = e.message!;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      developer.log(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const ValueKey('email'),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Lütfen geçerli bir e-posta adresi girin.';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-posta adresi'),
                      onSaved: (value) {
                        _userEmail = value!;
                      },
                    ),
                    TextFormField(
                      key: const ValueKey('password'),
                      validator: (value) {
                        if (value == null || value.isEmpty || value.length < 6) {
                          return 'Şifreniz en az 6 karakter olmalıdır.';
                        }
                          return null;
                        },
                      decoration: const InputDecoration(labelText: 'Şifre'),
                      obscureText: true,
                      onSaved: (value) {
                        _userPassword = value!;
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _trySubmit,
                      child: Text(_isLogin ? 'Giriş Yap' : 'Kayıt Ol'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      child: Text(_isLogin ? 'Yeni hesap oluştur' : 'Zaten bir hesabım var'),
                    ),
                    if (_isLogin)
                      TextButton(
                        onPressed: _resetPassword,
                        child: const Text('Şifremi unuttum'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}