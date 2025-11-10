import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget { 
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser; 
  Map<String, dynamic>? _userData; 
  bool _isLoading = true; 
  String? _errorMessage; // Hata mesajı için yeni değişken

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _currentUser = FirebaseAuth.instance.currentUser; 

    if (_currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data();
            _isLoading = false;
            _errorMessage = null; // Başarılıysa hata mesajını temizle
          });
        } else {
          // Firestore'da kullanıcı bilgisi bulunamadı (Auth'da var ama Firestore'da yok)
          setState(() {
            _isLoading = false;
            _errorMessage = 'Profil verisi henüz veritabanına kaydedilmemiş.';
          });
        }
      } catch (e) {
        // Ağ hatası veya Güvenlik Kuralı hatası gibi bir sorun oluştu
        print('Kullanıcı verileri çekilirken HATA OLUŞTU: $e');
        setState(() {
          _errorMessage = 'Veri çekme hatası! Güvenlik kurallarını veya ağ bağlantınızı kontrol edin.';
          _isLoading = false;
        });
      }
    } else {
      // Kullanıcı oturum açmamış olmalı (bu normalde StreamBuilder sayesinde olmaz)
      setState(() {
        _isLoading = false;
        _errorMessage = 'Oturum açmış kullanıcı bulunamadı.';
      });
    }
  }
  
  // Çıkış (Logout) fonksiyonunu daha güvenli hale getirelim
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    // Ana sayfaya dön ve tüm rotaları sil
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // E-posta bilgisini her zaman _currentUser nesnesinden çekelim, bu daha sağlamdır.
    final String userEmail = _currentUser?.email ?? 'E-posta Yok';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) 
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 50),
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!, // Hata mesajını kullanıcıya göster
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadUserData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tekrar Dene'),
                        )
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Profil fotoğrafı (varsa)
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: _userData!['profileImageUrl'] != null &&
                                  _userData!['profileImageUrl'].isNotEmpty
                              ? NetworkImage(_userData!['profileImageUrl'])
                              : null, 
                          child: _userData!['profileImageUrl'] == null ||
                                  _userData!['profileImageUrl'].isEmpty
                              ? const Icon(Icons.account_circle, size: 120, color: Colors.grey) 
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _userData!['username'] ?? 'Kullanıcı Adı Yok',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        // E-posta bilgisini Auth'dan alınan bilgiyi kullanarak göster
                        Text(
                          userEmail, 
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        // Diğer profil bilgileri (bio, location vb.)
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text('Hakkımda'),
                            subtitle: Text(_userData!['bio'] ?? 'Biyografi henüz eklenmedi.'),
                          ),
                        ),
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            leading: const Icon(Icons.location_on),
                            title: const Text('Konum'),
                            subtitle: Text(_userData!['location'] ?? 'Konum bilgisi yok.'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Katkı Özetleri
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn('Takipçi', _userData!['followersCount'] ?? 0),
                            _buildStatColumn('Takip Edilen', _userData!['followingCount'] ?? 0),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Column _buildStatColumn(String title, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 15, color: Colors.grey),
        ),
      ],
    );
  }
}