import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

import '../database/user_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserRepository _userRepository = UserRepository();
  var _isLogin = true;
  var _userEmail = '';
  var _userUsername = '';
  var _userBio = '';
  var _userLocation = '';
  var _userPassword = '';

  void _trySubmit() async {
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();

    if (isValid) {
      _formKey.currentState!.save();

      // Verinin yakalandığını gösteren log
      developer.log(
        'DEBUG: Form Values Saved -> Username: $_userUsername, Bio: $_userBio, Location: $_userLocation',
      );

      try {
        if (_isLogin) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _userEmail,
            password: _userPassword,
          );
        } else {
          // Kayıt ol
          final UserCredential userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: _userEmail,
                password: _userPassword,
              );

          // Yerel, kesin String değişkenleri oluştur.
          final String finalUsername = _userUsername.toString();
          final String finalBio = _userBio.toString();
          final String finalLocation = _userLocation.toString();

          // 1. Kullanıcı adını Firebase Auth nesnesine ayarla (displayName güncellenir)
          await userCredential.user?.updateDisplayName(finalUsername);

          // 2. Firestore'a tüm özel verileri KAYDET
          try {
            await _userRepository.upsertUserProfile(
              uid: userCredential.user!.uid,
              email: _userEmail,
              username: finalUsername,
              profileImageUrl: userCredential.user?.photoURL ?? '',
              bio: finalBio,
              location: finalLocation,
            );
            developer.log(
              'DEBUG: Firestore Write SUCCESS for user: ${userCredential.user!.uid}',
            );
          } catch (e) {
            developer.log(
              'HATA: Firestore\'a profil belgesi yazma başarısız: $e',
            );
          }
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
            content: Text(
              'Şifre sıfırlama bağlantısı $_userEmail adresine gönderildi.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message =
          'Şifre sıfırlama e-postası gönderilirken bir hata oluştu.';
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
                      decoration: const InputDecoration(
                        labelText: 'E-posta adresi',
                      ),
                      onSaved: (value) {
                        _userEmail = value ?? '';
                      },
                    ),
                    // --- Kayıt Olma Alanları ---
                    if (!_isLogin)
                      TextFormField(
                        key: const ValueKey('username'),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              value.length < 4) {
                            return 'Kullanıcı adı en az 4 karakter olmalıdır.';
                          }
                          return null;
                        },
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı Adı',
                        ),
                        onSaved: (value) {
                          _userUsername = value ?? '';
                        },
                      ),
                    if (!_isLogin)
                      TextFormField(
                        key: const ValueKey('bio'),
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'Biyografi (Opsiyonel)',
                        ),
                        onSaved: (value) {
                          _userBio = value ?? '';
                        },
                      ),
                    if (!_isLogin)
                      TextFormField(
                        key: const ValueKey('location'),
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'Konum (Opsiyonel)',
                        ),
                        onSaved: (value) {
                          _userLocation = value ?? '';
                        },
                      ),
                    // --- Kayıt Olma Alanları Bitti ---
                    TextFormField(
                      key: const ValueKey('password'),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            value.length < 6) {
                          return 'Şifreniz en az 6 karakter olmalıdır.';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(labelText: 'Şifre'),
                      obscureText: true,
                      onSaved: (value) {
                        _userPassword = value ?? '';
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
                      child: Text(
                        _isLogin
                            ? 'Yeni hesap oluştur'
                            : 'Zaten bir hesabım var',
                      ),
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
