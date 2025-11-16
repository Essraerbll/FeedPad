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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    super.dispose();
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
          if (mounted) { 
            setState(() {
              _userData = userDoc.data();
              _isLoading = false;
              _errorMessage = null;
            });
          }
        } else {
          // Doküman yoksa, otomatik oluşturmayı durduruyoruz (Veri yarışını engeller)
          if (mounted) { 
            setState(() {
              _isLoading = false;
              _errorMessage = 'Profil verisi veritabanında bulunamadı. Lütfen "Tekrar Dene/Oluştur" butonuna basın.'; 
            });
          }
        }
      } catch (e) {
        if (mounted) { 
          setState(() {
            _errorMessage = 'Veri çekme hatası! Güvenlik kurallarını veya ağ bağlantınızı kontrol edin.';
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) { 
        setState(() {
          _isLoading = false;
          _errorMessage = 'Oturum açmış kullanıcı bulunamadı.';
        });
      }
    }
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çıkış yapılamadı. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Eğer profil dokümanı yoksa, basit bir default profil oluşturur.
  Future<void> _createDefaultProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) { 
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Bu metod, kullanıcı manuel olarak isterse boş bir şablon oluşturur.
      // AuthScreen'den gelen username'i kullanır.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email ?? '',
        'username': user.displayName ?? 'Kullanıcı',
        'profileImageUrl': user.photoURL ?? '', 
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'location': '',
        'bio': '',
        'followersCount': 0,
        'followingCount': 0,
      }, SetOptions(merge: true));

      // Yeniden yükle
      await _loadUserData();
    } catch (e) {
      if (mounted) { 
        setState(() {
          _isLoading = false;
          _errorMessage = 'Profil oluşturulamadı: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                        const SizedBox(height: 20),
                        // Tekrar Dene/Oluştur butonu
                        ElevatedButton.icon(
                          onPressed: _createDefaultProfile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tekrar Dene/Oluştur'),
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
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: _userData?['profileImageUrl'] != null &&
                                  _userData!['profileImageUrl'].isNotEmpty
                              ? NetworkImage(_userData!['profileImageUrl'])
                              : null,
                          child: _userData?['profileImageUrl'] == null ||
                                  _userData!['profileImageUrl'].isEmpty
                              ? const Icon(Icons.account_circle, size: 120, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _userData?['username'] ?? 'Kullanıcı Adı Yok', 
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _currentUser?.email ?? 'E-posta Yok',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        
                        // Hakkımda (Biyografi) Kartı
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text('Hakkımda'),
                            subtitle: Text(_userData?['bio'] ?? 'Biyografi henüz eklenmedi.'), 
                          ),
                        ),
                        
                        // Konum Kartı
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            leading: const Icon(Icons.location_on),
                            title: const Text('Konum'),
                            subtitle: Text(_userData?['location'] ?? 'Konum bilgisi yok.'),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        // Katkı Özetleri
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn('Takipçi', _userData?['followersCount'] ?? 0),
                            _buildStatColumn('Takip Edilen', _userData?['followingCount'] ?? 0),
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