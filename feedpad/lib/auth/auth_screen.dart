import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  var _isLogin = true;
  var _userEmail = '';
  var _userName = '';
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
          
          final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _userEmail,
            password: _userPassword,
          );
          
          // EN GÜVENİLİR YÖNTEM: Kullanıcı nesnesini doğrudan userCredential'dan al
          final User? firebaseUser = userCredential.user; 
          
          if (firebaseUser != null) {
            try {
              print('Firestore\'a kaydedilen UID: ${firebaseUser.uid}');
              // Kullanıcı ID'sini kullanarak profili otomatik kaydet
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(firebaseUser.uid)
                  .set({
                'email': _userEmail,
                'username': _userName,
                'profileImageUrl': '',
                'createdAt': Timestamp.now(),
                'updatedAt': Timestamp.now(),
                'location': '',
                'bio': '',
                'followersCount': 0,
                'followingCount': 0,
              });
              print('Kullanıcı bilgileri Firestore\'a başarıyla kaydedildi.');
            } catch (firestoreError) {
              print('Firestore\'a kullanıcı bilgileri kaydedilirken HATA: $firestoreError');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kayıt başarılı, ancak profil kaydedilemedi: $firestoreError'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else {
            print('HATA: Kayıt başarılı ama kullanıcı nesnesi alınamadı.');
          }
        }
      } on FirebaseAuthException catch (e) {
        String message = 'Bir hata oluştu, lütfen kontrol edin!';
        if (e.message != null) {
          message = e.message!;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } catch (e) {
        print(e);
      }
    }
  }

  void _resetPassword() async {
    if (_userEmail.isEmpty || !_userEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen geçerli bir e-posta adresi girin.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _userEmail);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Şifre sıfırlama bağlantısı $_userEmail adresine gönderildi.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Şifre sıfırlama e-postası gönderilirken bir hata oluştu.';
      if (e.message != null) {
        message = e.message!;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      print(e);
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
                    if (!_isLogin)
                      TextFormField(
                        key: const ValueKey('username'),
                        validator: (value) {
                          if (value == null || value.isEmpty || value.length < 4) {
                            return 'Lütfen en az 4 karakterli bir kullanıcı adı girin.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(labelText: 'Kullanıcı Adı'),
                        onSaved: (value) {
                          _userName = value!;
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