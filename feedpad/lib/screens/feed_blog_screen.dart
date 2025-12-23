import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'other_user_profile_screen.dart';

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
      final response = await _apiService.get('/posts/feed');
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

  Widget _buildImage(String imageUrl) {
    Widget fallback = Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 64, color: Color(0xFF90CAF9)),
      ),
    );

    try {
      if (imageUrl.startsWith('data:image')) {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, fit: BoxFit.cover, height: 220, width: double.infinity),
        );
      }
    } catch (_) {
      return fallback;
    }

    return fallback;
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final user = post['user'] ?? {};
    String name = user['name'] ?? post['userName'] ?? post['username'] ?? '';
    if (name.isEmpty) {
      final uid = post['userId'];
      if (uid is String && uid.isNotEmpty) {
        name = uid.contains('@') ? uid.split('@').first : uid;
      } else {
        name = 'Bilinmiyor';
      }
    }
    final username = user['username'] ?? '';
    final caption = post['caption'] ?? '';
    final imageUrl = post['imageUrl'] ?? '';
    final likes = post['likes'] ?? 0;
    final location = post['location'] ?? '';
    final isLiked = post['liked'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE3F2FD),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                      if ((username as String).isNotEmpty)
                        Text('@$username', style: const TextStyle(color: Color(0xFF607D8B), fontSize: 12)),
                    ],
                  ),
                ),
                if ((location as String).isNotEmpty)
                  const Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Color(0xFF64B5F6)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if ((imageUrl as String).isNotEmpty)
              _buildImage(imageUrl)
            else
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.image, size: 64, color: Color(0xFF90CAF9)),
                ),
              ),
            const SizedBox(height: 10),
            if (caption.isNotEmpty)
              Text(
                caption,
                style: const TextStyle(fontSize: 14, color: Color(0xFF263238)),
              ),
            if (caption.isNotEmpty) const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: const Color(0xFF1E88E5)),
                  onPressed: () => _toggleLike(post),
                ),
                Text('$likes', style: const TextStyle(color: Color(0xFF546E7A))),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.comment_bank_outlined, size: 20, color: Colors.orange),
                  onPressed: () => _openPostDetails(post),
                ),
              ],
            )
          ],
        ),
      ),
    );
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
                              backgroundImage: userProfileImage.isNotEmpty
                                  ? NetworkImage(userProfileImage)
                                  : null,
                              child: userProfileImage.isEmpty
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                            title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () {
                              // Kullanıcının kendi profili değilse başka kullanıcının profilini aç
                              final authService = Provider.of<AuthService>(context, listen: false);
                              final currentUserEmail = authService.currentUser?.email ?? '';
                              final postUserId = post['userId'] ?? '';
                              
                              if (postUserId != currentUserEmail && postUserId.isNotEmpty) {
                                // Başka kullanıcının profili - OtherUserProfileScreen'e git
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
            'text': _commentController.text,
            'userProfileImage': null,
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
        title: const Text('Post'),
        elevation: 0,
        backgroundColor: const Color(0xFF64B5F6),
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
                                child: Text(
                                  senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Post image
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
                        // Post caption
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
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF64B5F6),
                              backgroundImage: comment['userProfileImage'] != null && 
                                  (comment['userProfileImage'] as String?)?.isNotEmpty == true
                                  ? NetworkImage(comment['userProfileImage'])
                                  : null,
                              child: comment['userProfileImage'] == null || 
                                  (comment['userProfileImage'] as String?)?.isEmpty != false
                                  ? const Icon(Icons.person, color: Colors.white, size: 18)
                                  : null,
                            ),
                            title: Text(
                              comment['userName'] ?? 'Anonymous',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
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
