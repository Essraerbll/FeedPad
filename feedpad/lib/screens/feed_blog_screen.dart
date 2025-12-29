import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../animations/route_animations.dart';
import 'other_user_profile_screen.dart';
import 'profile_screen.dart';
import 'post_details_screen.dart';

// Helper function to get image provider from URL or base64
ImageProvider? _getImageProvider(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) return null;
  
  try {
    if (imageUrl.startsWith('data:image')) {
      final base64Str = imageUrl.split(',').last;
      final bytes = base64Decode(base64Str);
      return MemoryImage(bytes);
    } else {
      return NetworkImage(imageUrl);
    }
  } catch (e) {
    debugPrint('Error loading image: $e');
    return null;
  }
}

class FeedBlogScreen extends StatefulWidget {
  const FeedBlogScreen({super.key});

  @override
  State<FeedBlogScreen> createState() => _FeedBlogScreenState();
}

class _FeedBlogScreenState extends State<FeedBlogScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final userId = auth.currentUser?.email ?? '';
      debugPrint('🔄 Loading feed for user: $userId');
      final response = await _apiService.get('/posts/feed?requesterId=$userId');
      debugPrint('📥 Feed response received: success=${response['success']}, posts count=${(response['posts'] as List?)?.length ?? 0}');
      
      if (response['success'] == true) {
        final postsList = response['posts'];
        if (postsList != null && postsList is List) {
          setState(() {
            _posts = List<Map<String, dynamic>>.from(postsList);
          });
          debugPrint('✅ Feed loaded successfully: ${_posts.length} posts');
        } else {
          debugPrint('⚠️ Posts list is null or not a List: $postsList');
          setState(() {
            _posts = [];
          });
        }
      } else {
        debugPrint('❌ Feed response success is false: $response');
        setState(() {
          _posts = [];
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Feed load error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feed yüklenemedi: $e')),
        );
      }
      setState(() {
        _posts = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.currentUser?.email;
    if (userId == null) return;

    final postId = post['id'];
    final isLiked = post['liked'] == true;

    // Optimistic update
    setState(() {
      post['liked'] = !isLiked;
      final currentLikes = post['likes'] ?? 0;
      post['likes'] = isLiked ? (currentLikes - 1).clamp(0, 1 << 31) : currentLikes + 1;
    });

    try {
      await _apiService.post('/posts/like', {
        'postId': postId,
        'userId': userId,
      });
    } catch (e) {
      // rollback on failure
      setState(() {
        post['liked'] = isLiked;
        post['likes'] = isLiked ? (post['likes'] ?? 1) + 1 : (post['likes'] ?? 0) - 1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Beğeni hatası: $e')),
        );
      }
    }
  }

  void _openPostDetails(Map<String, dynamic> post) {
    Navigator.push(
      context,
      SlideRightRoute(
        page: PostDetailsScreen(post: post, apiService: _apiService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F1FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFeed,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF64B5F6)))
              : _posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.pets,
                            size: 64,
                            color: Color(0xFF90A4AE),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Henüz post yok',
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF90A4AE),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loadFeed,
                            child: const Text('Yenile'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                    final post = _posts[index];
                    final user = post['user'] ?? {};
                    String userName = user['name'] ?? post['userName'] ?? user['username'] ?? '';
                    String username = user['username'] ?? post['username'] ?? 'username';
                    if (userName.isEmpty) {
                      final uid = post['userId'];
                      if (uid is String && uid.isNotEmpty) {
                        userName = uid.contains('@') ? uid.split('@').first : uid;
                      } else {
                        userName = 'Bilinmiyor';
                      }
                    }
                    final userProfileImage = user['profileImage'] ?? post['userProfileImage'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE3F2FD),
                              backgroundImage: _getImageProvider(userProfileImage),
                              child: userProfileImage.isEmpty
                                  ? Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                      style: const TextStyle(
                                        color: Color(0xFF1E88E5),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  '@$username',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF90A4AE),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              // Kullanıcının kendi profili mi kontrol et
                              final authService = Provider.of<AuthService>(context, listen: false);
                              final currentUserEmail = authService.currentUser?.email ?? '';
                              final currentUserName = authService.currentUser?.name ?? '';
                              final postUserId = post['userId'] ?? '';
                              
                              debugPrint('=== Profile Tap Debug ===');
                              debugPrint('Current User Email: $currentUserEmail');
                              debugPrint('Current User Name: $currentUserName');
                              debugPrint('Post User ID: $postUserId');
                              debugPrint('Post User Name: $userName');
                              debugPrint('Email match: ${postUserId == currentUserEmail}');
                              debugPrint('Name match: ${userName == currentUserName}');
                              
                              // Kendi profili mi? - Email veya isim eşleşmesi kontrolü
                              final isOwnProfile = (postUserId == currentUserEmail && currentUserEmail.isNotEmpty) ||
                                                  (userName == currentUserName && currentUserName.isNotEmpty);
                              
                              if (isOwnProfile) {
                                // Kendi profili - ProfileScreen'i aç
                                debugPrint('Opening ProfileScreen (own profile)');
                                Navigator.push(
                                  context,
                                  SlideRightRoute(
                                    page: const ProfileScreen(showAppBar: true),
                                  ),
                                );
                              } else if (postUserId.isNotEmpty || userName.isNotEmpty) {
                                // Başka kullanıcının profili - OtherUserProfileScreen'e git
                                debugPrint('Opening OtherUserProfileScreen');
                                Navigator.push(
                                  context,
                                  SlideRightRoute(
                                    page: OtherUserProfileScreen(
                                      user: {
                                        'id': postUserId,
                                        'email': postUserId,
                                        'name': userName,
                                        'bio': user['bio'] ?? '🐾 Pet lover',
                                        'profileImage': userProfileImage,
                                        'postsCount': 0,
                                        'followersCount': 0,
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(post['caption'] ?? '', style: const TextStyle(fontSize: 16)),
                          ),
                          if (post['imageUrl'] != null && (post['imageUrl'] as String).isNotEmpty)
                            Image.network(
                              post['imageUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  post['liked'] == true ? Icons.favorite : Icons.favorite_border,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () => _toggleLike(post),
                              ),
                              Text('${post['likes'] ?? 0}', style: const TextStyle(color: Color(0xFF546E7A))),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.comment_bank_outlined, size: 20, color: Colors.orange),
                                onPressed: () => _openPostDetails(post),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}