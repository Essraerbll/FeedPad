import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

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
    final name = user['name'] ?? post['userName'] ?? user['username'] ?? 'Bilinmiyor';
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
                    final userName = user['name'] ?? post['userName'] ?? user['username'] ?? 'Bilinmiyor';
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
    final senderName = user['name'] ?? widget.post['userName'] ?? user['username'] ?? 'Bilinmiyor';
    final caption = widget.post['caption'] ?? widget.post['content'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Post Detayları')),
      body: Container(
        color: Colors.blue.shade50,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.post['imageUrl'] != null && (widget.post['imageUrl'] as String).isNotEmpty)
                    Image.network(
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
                  const SizedBox(height: 20),
                  if (caption.isNotEmpty)
                    Text(caption, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 20),
                  Text('Paylaşan: $senderName', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 20),
                  const Text('Yorumlar:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Henüz yorum yok', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF64B5F6),
                            backgroundImage: comment['userProfileImage'] != null && 
                                (comment['userProfileImage'] as String?)?.isNotEmpty == true
                                ? NetworkImage(comment['userProfileImage'])
                                : null,
                            child: comment['userProfileImage'] == null || 
                                (comment['userProfileImage'] as String?)?.isEmpty != false
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          title: Text(comment['userName'] ?? 'Unknown'),
                          subtitle: Text(comment['text'] ?? ''),
                        );
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        hintText: 'Yorum yazın...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _isSubmitting ? null : (_) => _submitComment(),
                    ),
                  ),
                  IconButton(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.blue),
                    onPressed: _isSubmitting ? null : _submitComment,
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
