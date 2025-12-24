import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'other_user_profile_screen.dart';
import 'profile_screen.dart';

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
      final response = await _apiService.get('/posts/feed?requesterId=$userId');
      if (response['success'] == true) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(response['posts'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Feed load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feed yüklenemedi: $e')),
        );
      }
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
      MaterialPageRoute(
        builder: (context) => PostDetailsScreen(post: post, apiService: _apiService),
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
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileScreen(showAppBar: true),
                                  ),
                                );
                              } else if (postUserId.isNotEmpty || userName.isNotEmpty) {
                                // Başka kullanıcının profili - OtherUserProfileScreen'e git
                                debugPrint('Opening OtherUserProfileScreen');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OtherUserProfileScreen(
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

class PostDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final ApiService apiService;

  const PostDetailsScreen({Key? key, required this.post, required this.apiService}) : super(key: key);

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  late TextEditingController _commentController;
  late List<Map<String, dynamic>> _comments;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _comments = widget.post['comments'] is List ? List<Map<String, dynamic>>.from(widget.post['comments']) : [];
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorum yazınız')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final userId = auth.currentUser?.email;
      final userName = auth.currentUser?.name ?? 'Anonymous';
      final userEmail = auth.currentUser?.email ?? '';
      final username = userEmail.split('@').first;

      if (userId == null) {
        throw Exception('Kullanıcı bilgisi bulunamadı');
      }

      final response = await widget.apiService.post('/posts/comment', {
        'postId': widget.post['id'],
        'userId': userId,
        'userName': userName,
        'text': _commentController.text,
      });

      if (response['success'] == true) {
        setState(() {
          _comments.add({
            'userId': userId,
            'userName': userName,
            'username': username,
            'text': _commentController.text,
            'userProfileImage': response['comment']?['userProfileImage'] ?? '',
          });
          _commentController.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yorum eklendi!'),
              backgroundColor: Color(0xFF66BB6A),
            ),
          );
        }
      } else {
        throw Exception(response['message'] ?? 'Yorum eklenemedi');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.post['user'] ?? {};
    String senderName = user['name'] ?? widget.post['userName'] ?? user['username'] ?? '';
    String username = user['username'] ?? widget.post['username'] ?? 'username';
    final userProfileImage = user['profileImage'] ?? widget.post['userProfileImage'] ?? '';
    if (senderName.isEmpty) {
      final uid = widget.post['userId'];
      if (uid is String && uid.isNotEmpty) {
        senderName = uid.contains('@') ? uid.split('@').first : uid;
      } else {
        senderName = 'Bilinmiyor';
      }
    }
    final caption = widget.post['caption'] ?? widget.post['content'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Post',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF9DB8E8),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: const Color(0xFFE8F1FA),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Post header with sender info
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF64B5F6),
                                backgroundImage: _getImageProvider(userProfileImage),
                                child: userProfileImage.isEmpty
                                    ? Text(
                                        senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      senderName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1E2A3A),
                                      ),
                                    ),
                                    Text(
                                      '@$username',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF90A4AE),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Post caption FIRST (before image)
                        if (caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              caption,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF263238),
                                height: 1.4,
                              ),
                            ),
                          ),
                        // Post image SECOND (after caption)
                        if (widget.post['imageUrl'] != null && (widget.post['imageUrl'] as String).isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                            child: Image.network(
                              widget.post['imageUrl'],
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
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Comments section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Comments (${_comments.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2A3A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_comments.isEmpty)
                    Card(
                      color: Colors.grey[100],
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'No comments yet',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final commentProfileImage = comment['userProfileImage'] ?? '';
                        final commentName = comment['userName'] ?? 'Anonymous';
                        final commentUsername = comment['username'] ??
                            (comment['userId'] is String && (comment['userId'] as String).contains('@')
                                ? (comment['userId'] as String).split('@').first
                                : (comment['userId'] ?? 'username'));
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF64B5F6),
                              backgroundImage: _getImageProvider(commentProfileImage),
                              child: commentProfileImage.isEmpty
                                  ? Text(
                                      commentName.isNotEmpty ? commentName[0].toUpperCase() : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  commentName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '@$commentUsername',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF90A4AE),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              comment['text'] ?? '',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            // Comment input
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2),
                        ),
                      ),
                      onSubmitted: _isSubmitting ? null : (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF64B5F6),
                    child: IconButton(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isSubmitting ? null : _submitComment,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
