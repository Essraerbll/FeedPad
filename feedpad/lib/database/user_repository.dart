import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcı profil verilerini yöneten Firestore katmanı.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Kullanıcının profil verilerini döndürür. Belge yoksa `null` verir.
  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.data();
  }

  /// Kullanıcı profili oluşturur veya var olan belgeyi günceller.
  Future<void> upsertUserProfile({
    required String uid,
    required String email,
    required String username,
    String profileImageUrl = '',
    String bio = '',
    String location = '',
    int followersCount = 0,
    int followingCount = 0,
  }) {
    final now = Timestamp.now();

    return _users.doc(uid).set({
      'email': email,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'location': location,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }
}
