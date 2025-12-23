import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'messaging_screen.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const OtherUserProfileScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final ApiService _apiService = ApiService();
  bool _isFollowing = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _userPosts = [];

  @override
  void initState() {
    super.initState();
    _loadUserPosts();
  }

  Future<void> _loadUserPosts() async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.user['email'] ?? widget.user['id'];
      final response = await _apiService.get('/posts/user/$userId');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user['name']),
        elevation: 0,
        backgroundColor: const Color(0xFF64B5F6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
                  // Profile Picture
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF64B5F6),
                          Color(0xFF90CAF9),
                          Color(0xFF42A5F5)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFE3F2FD),
                      backgroundImage: widget.user['profileImage'] != null
                          ? NetworkImage(widget.user['profileImage'])
                          : null,
                      child: widget.user['profileImage'] == null
                          ? Text(
                              widget.user['name'][0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64B5F6),
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
                  const SizedBox(height: 8),
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
                        widget.user['followersCount']?.toString() ?? '0',
                        'Followers',
                      ),
                      _buildStatColumn('0', 'Following'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isFollowing = !_isFollowing;
                            });
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
                          },
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
                          child: Text(
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
                            final currentUserName = authService.currentUser?.name ?? 'You';
                            
                            // Konuşma objesi oluştur veya mevcut konuşmayı bul
                            final conversation = {
                              'id': 'conv_${widget.user['id']}',
                              'userName': widget.user['name'],
                              'userImage': widget.user['profileImage'],
                              'timestamp': DateTime.now(),
                              'unread': false,
                              'messages': [],
                            };
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailScreen(
                                  conversation: conversation,
                                  currentUserName: currentUserName,
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
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post['caption'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF263238),
                                    ),
                                  ),
                                  if (post['imageUrl'] != null &&
                                      (post['imageUrl'] as String).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          post['imageUrl'],
                                          fit: BoxFit.cover,
                                          height: 150,
                                          width: double.infinity,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              height: 150,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFFE3F2FD),
                                                    Color(0xFFBBDEFB)
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.image,
                                                  size: 60,
                                                  color: Color(0xFF90CAF9),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.favorite_outline,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        post['likes']?.toString() ?? '0',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF546E7A),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(
                                        Icons.comment_outlined,
                                        size: 18,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        post['comments']?.length?.toString() ??
                                            '0',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF546E7A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
