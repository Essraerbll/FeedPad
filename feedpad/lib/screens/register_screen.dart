import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.signUpWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
    } else if (mounted) {
      // Başarılı kayıt
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesap başarıyla oluşturuldu!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesap Oluştur'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // İsim alanı
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Ad Soyad',
                    hintText: 'Ahmet Yılmaz',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen adınızı girin';
                    }
                    if (value.length < 2) {
                      return 'Ad en az 2 karakter olmalı';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Kullanıcı adı alanı (opsiyonel)
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Kullanıcı Adı (opsiyonel)',
                    hintText: 'ornek_kullanici',
                    prefixIcon: const Icon(Icons.alternate_email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Benzersiz bir kullanıcı adı seçin',
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (value.length < 3) {
                        return 'Kullanıcı adı en az 3 karakter olmalı';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                        return 'Sadece harf, rakam ve _ kullanın';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Telefon alanı (opsiyonel)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Telefon (opsiyonel)',
                    hintText: '+90 555 123 4567',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      // Sadece rakam ve + kontrolü
                      if (!RegExp(r'^[+0-9\s]+$').hasMatch(value)) {
                        return 'Geçerli bir telefon numarası girin';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // E-posta alanı
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen e-posta adresinizi girin';
                    }
                    if (!value.contains('@')) {
                      return 'Geçerli bir e-posta adresi girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Şifre alanı
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen şifrenizi girin';
                    }
                    if (value.length < 6) {
                      return 'Şifre en az 6 karakter olmalıdır';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Şifre tekrar alanı
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Şifre Tekrar',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen şifrenizi tekrar girin';
                    }
                    if (value != _passwordController.text) {
                      return 'Şifreler eşleşmiyor';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Kayıt ol butonu
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Kayıt Ol',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

