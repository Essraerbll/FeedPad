import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'messaging_screen.dart';
import 'post_details_screen.dart';

// Shared helper to support network or base64 profile images
ImageProvider? _getImageProvider(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) return null;
  try {
    if (imageUrl.startsWith('data:image')) {
      final base64Str = imageUrl.split(',').last;
      final bytes = base64Decode(base64Str);
      return MemoryImage(bytes);
    }
    return NetworkImage(imageUrl);
  } catch (e) {
    debugPrint('Error loading image: $e');
    return null;
  }
}

class OtherUserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const OtherUserProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final ApiService _apiService = ApiService();
  bool _isFollowing = false;
  bool _isLoading = false;
  bool _isLoadingFollow = false;
  List<Map<String, dynamic>> _userPosts = [];
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserPosts();
    _loadFollowStatus();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      final userId = widget.user['email'] ?? widget.user['id'];
      final response = await _apiService.get('/posts/stats/$userId');
      if (response['success'] == true) {
        setState(() {
          _followersCount = response['stats']['followers'] ?? 0;
          _followingCount = response['stats']['following'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }
  }

  Future<void> _loadFollowStatus() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final currentUserId = auth.currentUser?.email ?? '';
      final targetUserId = widget.user['email'] ?? widget.user['id'];
      
      final response = await _apiService.get('/posts/follow/status?followerId=$currentUserId&followingId=$targetUserId');
      if (response['success'] == true) {
        setState(() {
          _isFollowing = response['isFollowing'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoadingFollow) return;
    
    setState(() => _isLoadingFollow = true);
    
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final currentUserId = auth.currentUser?.email ?? '';
      final targetUserId = widget.user['email'] ?? widget.user['id'];
      
      final response = await _apiService.post('/posts/follow', {
        'followerId': currentUserId,
        'followingId': targetUserId,
      });
      
      if (response['success'] == true) {
        setState(() {
          _isFollowing = response['following'] ?? false;
          if (_isFollowing) {
            _followersCount++;
          } else {
            _followersCount = (_followersCount - 1).clamp(0, 999999);
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isFollowing
                    ? 'Following ${widget.user['name']}'
                    : 'Unfollowed ${widget.user['name']}',
              ),
              backgroundColor: const Color(0xFF64B5F6),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingFollow = false);
    }
  }

  Future<void> _loadUserPosts() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final requesterId = auth.currentUser?.email ?? '';
      final userId = widget.user['email'] ?? widget.user['id'];
      final response = await _apiService.get('/posts/user/$userId?requesterId=$requesterId');
      if (response['success'] == true) {
        setState(() {
          _userPosts = List<Map<String, dynamic>>.from(response['posts'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading user posts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.currentUser?.email;
    if (userId == null) return;

    final postId = post['id'] ?? '';
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
    }
  }

  void _openPostComments(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsScreen(
          post: post,
          apiService: _apiService,
          onCommentAdded: () {
            _loadUserPosts();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String _deriveUsernameFromPost(Map<String, dynamic> post) {
      final postUser = post['user'] as Map<String, dynamic>? ?? {};
      final postUsername = postUser['username'] ?? post['username'];
      if (postUsername is String && postUsername.trim().isNotEmpty) {
        return postUsername.trim();
      }
      final postUserId = post['userId'];
      if (postUserId is String && postUserId.contains('@')) {
        return postUserId.split('@').first;
      }
      return 'username';
    }

    final emailValue = widget.user['email'] as String? ?? '';
    final rawUsername = widget.user['username'] as String? ?? '';
    final profileUsername = () {
      if (rawUsername.trim().isNotEmpty && rawUsername.trim() != 'username') {
        return rawUsername.trim();
      }
      if (emailValue.contains('@')) {
        return emailValue.split('@').first;
      }
      if (_userPosts.isNotEmpty) {
        return _deriveUsernameFromPost(_userPosts.first);
      }
      final userNameField = widget.user['userName'];
      if (userNameField is String && userNameField.trim().isNotEmpty) {
        return userNameField.trim();
      }
      return 'username';
    }();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF9DB8E8),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Geri',
          ),
        ),
        title: Text(
          widget.user['name'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: CustomScrollView(
        slivers: [
          // Profile Header
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFE8F1FA),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Picture (uses same fallback as posts list)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF9DB8E8),
                          Color(0xFFBBDEFB),
                          Color(0xFF64B5F6)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFE3F2FD),
                      backgroundImage: _getImageProvider(
                        widget.user['profileImage'] ??
                        widget.user['userProfileImage'] ??
                        '',
                      ),
                      child: (widget.user['profileImage'] ?? widget.user['userProfileImage']) == null ||
                              (widget.user['profileImage'] ?? widget.user['userProfileImage']).toString().isEmpty
                          ? Text(
                              widget.user['name'][0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9DB8E8),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    widget.user['name'],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Username
                  Text(
                    '@$profileUsername',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF90A4AE),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Bio
                  Text(
                    widget.user['bio'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF546E7A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn(
                        _userPosts.length.toString(),
                        'Posts',
                      ),
                      _buildStatColumn(
                        _followersCount.toString(),
                        'Followers',
                      ),
                      _buildStatColumn(_followingCount.toString(), 'Following'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoadingFollow ? null : _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing
                                ? Colors.grey[300]
                                : const Color(0xFF64B5F6),
                            foregroundColor:
                                _isFollowing ? Colors.black87 : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoadingFollow
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  _isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final authService = Provider.of<AuthService>(context, listen: false);
                            final currentUserEmail = authService.currentUser?.email ?? '';
                            final currentUserName = authService.currentUser?.name ?? 'You';
                            final otherUserEmail = widget.user['email'] ?? '';
                            
                            if (otherUserEmail.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('User email not found'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            
                            // Create conversation ID by sorting emails
                            final conversationId = ([currentUserEmail, otherUserEmail]..sort()).join(':');
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailScreen(
                                  conversationId: conversationId,
                                  otherUserId: otherUserEmail,
                                  otherUserName: widget.user['name'],
                                  otherUsername: widget.user['username'] ?? (otherUserEmail.contains('@') ? otherUserEmail.split('@').first : ''),
                                  otherUserProfileImage: widget.user['profileImage'] ?? '',
                                  currentUserId: currentUserEmail,
                                  currentUserName: currentUserName,
                                  currentUserProfileImage: '',
                                  onMessagesUpdated: () {},
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.message),
                          label: const Text('Message'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64B5F6),
                            side: const BorderSide(
                              color: Color(0xFF64B5F6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                ],
              ),
            ),
          ),
          // Posts Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Posts (${_userPosts.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
          ),
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF64B5F6),
                    ),
                  ),
                )
              : _userPosts.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library_outlined,
                                size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'No posts yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final post = _userPosts[index];
                          final postUser = post['user'] ?? {};
                          String userName = postUser['name'] ?? post['userName'] ?? postUser['username'] ?? '';
                          final username = postUser['username'] ?? post['username'] ?? widget.user['username'] ?? 'username';
                          if (userName.isEmpty) {
                            final uid = post['userId'];
                            if (uid is String && uid.isNotEmpty) {
                              userName = uid.contains('@') ? uid.split('@').first : uid;
                            } else {
                              userName = 'User';
                            }
                          }
                          final userProfileImage = postUser['profileImage'] ?? post['userProfileImage'] ?? widget.user['profileImage'] ?? '';
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User header with avatar and name
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF64B5F6),
                                    backgroundImage: _getImageProvider(userProfileImage),
                                    child: userProfileImage.isEmpty
                                        ? Text(
                                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
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
                                ),
                                // Post caption
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Text(
                                    post['caption'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF263238),
                                    ),
                                  ),
                                ),
                                // Post image
                                if (post['imageUrl'] != null &&
                                    (post['imageUrl'] as String).isNotEmpty)
                                  Image.network(
                                    post['imageUrl'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 200,
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                // Like and comment row
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          post['liked'] == true
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _toggleLike(post),
                                      ),
                                      Text(
                                        post['likes']?.toString() ?? '0',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF546E7A),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.comment_bank_outlined,
                                          size: 20,
                                          color: Colors.orange,
                                        ),
                                        onPressed: () => _openPostComments(post),
                                      ),
                                      Text(
                                        post['comments'] is List
                                            ? post['comments'].length.toString()
                                            : post['comments']?.toString() ?? '0',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF546E7A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: _userPosts.length,
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64B5F6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF78909C),
          ),
        ),
      ],
    );
  }
}