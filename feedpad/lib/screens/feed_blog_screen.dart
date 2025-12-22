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

  Widget _buildStoryChip(Map<String, dynamic> post) {
    final user = post['user'] ?? {};
    final display = (user['name'] ?? 'User') as String;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF64B5F6), Color(0xFF42A5F5)],
            ),
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFE3F2FD),
            child: Text(
              display.isNotEmpty ? display[0].toUpperCase() : 'U',
              style: const TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 60,
          child: Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A)),
          ),
        ),
      ],
    );
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
    final name = user['name'] ?? 'User';
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
                const Icon(Icons.comment_bank_outlined, size: 20, color: Color(0xFF90A4AE)),
              ],
            )
          ],
        ),
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
              : ListView(
                  children: [
                    const SizedBox(height: 12),
                    // Stories style row
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemBuilder: (context, index) {
                          final item = _posts.isNotEmpty ? _posts[index % _posts.length] : {'user': {'name': 'Story'}};
                          return _buildStoryChip(item);
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemCount: _posts.isEmpty ? 5 : (_posts.length > 10 ? 10 : _posts.length),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Feed list
                    ..._posts.map(_buildPostCard),
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }
}
