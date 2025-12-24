import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'profile_dialogs.dart';import 'post_details_screen.dart';
class ProfileScreen extends StatefulWidget {
  final bool showAppBar;
  
  const ProfileScreen({super.key, this.showAppBar = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  String _bio = "🐾 Pet lover | FeedPad community member";
  String? _profileImageUrl;
  bool _isLoading = false;
  
  // Stats
  int _postsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  
  // Posts from API
  List<Map<String, dynamic>> _posts = [];
  
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
  
  // Helper widget to build image from URL or base64
  Widget _buildPostImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    
    try {
      if (imageUrl.startsWith('data:image')) {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
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
        );
      } else {
        return Image.network(
          imageUrl,
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
        );
      }
    } catch (e) {
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      );
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
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.email; // Using email as userId
    
    if (userId != null) {
      // Load stats
      try {
        final statsResponse = await _apiService.get('/posts/stats/$userId');
        if (statsResponse['success']) {
          setState(() {
            _postsCount = statsResponse['stats']['posts'] ?? 0;
            _followersCount = statsResponse['stats']['followers'] ?? 0;
            _followingCount = statsResponse['stats']['following'] ?? 0;
          });
        }
      } catch (e) {
        debugPrint('Error loading stats: $e');
      }
      
      // Load user profile data (including bio and profile image)
      try {
        final userResponse = await _apiService.get('/posts/user/$userId');
        if (userResponse['success']) {
          final userData = userResponse['user'];
          if (userData != null) {
            setState(() {
              if (userData['bio'] != null && userData['bio'].isNotEmpty) {
                _bio = userData['bio'];
              }
              if (userData['profileImage'] != null && userData['profileImage'].isNotEmpty) {
                _profileImageUrl = userData['profileImage'];
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading user profile: $e');
      }
      
      // Load posts
      try {
        final postsResponse = await _apiService.get('/posts/user/$userId?requesterId=$userId');
        if (postsResponse['success']) {
          setState(() {
            _posts = List<Map<String, dynamic>>.from(postsResponse['posts'] ?? []);
          });
        }
      } catch (e) {
        debugPrint('Error loading posts: $e');
      }
    }
    
    setState(() => _isLoading = false);
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => CreatePostDialog(
        apiService: _apiService,
        onPostCreated: _loadUserData,
      ),
    );
  }

  void _showEditPostDialog(Map<String, dynamic> post) {
    final captionController = TextEditingController(text: post['caption'] ?? '');
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Post'),
          content: SingleChildScrollView(
            child: TextField(
              controller: captionController,
              decoration: const InputDecoration(
                labelText: 'Caption',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              enabled: !isUpdating,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUpdating
                  ? null
                  : () async {
                      setState(() => isUpdating = true);
                      try {
                        final auth = Provider.of<AuthService>(context, listen: false);
                        final userId = auth.currentUser?.email;
                        final response = await _apiService.post('/posts/update', {
                          'postId': post['id'],
                          'userId': userId,
                          'caption': captionController.text,
                          'location': post['location'] ?? '',
                        });

                        if (response['success'] == true) {
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Post updated successfully!'),
                                backgroundColor: Color(0xFF66BB6A),
                              ),
                            );
                            _loadUserData();
                          }
                        } else {
                          throw Exception(response['message'] ?? 'Update failed');
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
                        setState(() => isUpdating = false);
                      }
                    },
              child: isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeletePostConfirm(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final auth = Provider.of<AuthService>(context, listen: false);
                final userId = auth.currentUser?.email;
                final response = await _apiService.post('/posts/delete', {
                  'postId': post['id'],
                  'userId': userId,
                });

                if (response['success'] == true) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post deleted successfully!'),
                        backgroundColor: Color(0xFF66BB6A),
                      ),
                    );
                    _loadUserData();
                  }
                } else {
                  throw Exception(response['message'] ?? 'Delete failed');
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => EditProfileDialog(
        apiService: _apiService,
        currentBio: _bio,
        currentProfileImage: _profileImageUrl,
        onProfileUpdated: () {
          // Force reload and setState
          setState(() => _isLoading = true);
          _loadUserData();
        },
      ),
    );
  }

  void _openPostDetails(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsScreen(
          post: post,
          apiService: _apiService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.showAppBar ? AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF9DB8E8),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ) : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF9DB8E8)))
            : CustomScrollView(
          slivers: [
            // Profile Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Profile Picture and Stats
                    Row(
                      children: [
                        // Profile Picture with gradient border
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF9DB8E8), Color(0xFFBBDEFB), Color(0xFF64B5F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: const Color(0xFFE3F2FD),
                              backgroundImage: _getImageProvider(_profileImageUrl),
                              child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                                  ? const Icon(Icons.pets, size: 45, color: Color(0xFF9DB8E8))
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Stats
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn('Posts', _postsCount.toString(), const Color(0xFF64B5F6)),
                              _buildStatColumn('Followers', _followersCount.toString(), const Color(0xFF42A5F5)),
                              _buildStatColumn('Following', _followingCount.toString(), const Color(0xFF90CAF9)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Name and Bio
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser?.name ?? 'Pet Owner',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${currentUser?.username ?? 'username'}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF90A4AE),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _bio,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF546E7A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: OutlinedButton.icon(
                            onPressed: _showEditProfileDialog,
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit Profile'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64B5F6),
                              side: const BorderSide(color: Color(0xFF64B5F6), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _showCreatePostDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Post'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF64B5F6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Divider
                    Divider(color: Colors.grey[300], height: 1),
                  ],
                ),
              ),
            ),
            // Posts List
            _posts.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No posts yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Share your first post!',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showCreatePostDialog,
                            icon: const Icon(Icons.add_a_photo),
                            label: const Text('Create Post'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF64B5F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                                  backgroundColor: const Color(0xFF64B5F6),
                                  backgroundImage: _getImageProvider(userProfileImage),
                                  child: userProfileImage.isEmpty
                                      ? const Icon(Icons.person, color: Colors.white)
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
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditPostDialog(post);
                                    } else if (value == 'delete') {
                                      _showDeletePostConfirm(post);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    const PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(post['caption'] ?? '', style: const TextStyle(fontSize: 16)),
                              ),
                              if (post['imageUrl'] != null && (post['imageUrl'] as String).isNotEmpty)
                                _buildPostImage(post['imageUrl']),
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
                      childCount: _posts.length,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
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

class CommentsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Container(
        color: Colors.blue.shade50,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  // Add dynamic comments here
                  Text('No comments yet.', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) {
                        // Handle comment submission
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: () {
                      // Handle send action
                    },
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
