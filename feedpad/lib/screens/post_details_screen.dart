import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

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

class PostDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final ApiService apiService;
  final VoidCallback? onCommentAdded;

  const PostDetailsScreen({
    Key? key,
    required this.post,
    required this.apiService,
    this.onCommentAdded,
  }) : super(key: key);

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
    
    // Debug: Profil resimlerini kontrol et
    debugPrint('=== POST DETAILS SCREEN INIT ===');
    debugPrint('Post data keys: ${widget.post.keys.toList()}');
    debugPrint('Post user object: ${widget.post['user']}');
    debugPrint('Post userProfileImage: ${widget.post['userProfileImage']}');
    debugPrint('Comments count: ${_comments.length}');
    if (_comments.isNotEmpty) {
      debugPrint('First comment userProfileImage: ${_comments[0]['userProfileImage']}');
      debugPrint('First comment userName: ${_comments[0]['userName']}');
    }
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

        widget.onCommentAdded?.call();

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

  List<Widget> _buildAppBarActions() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUserId = auth.currentUser?.email ?? '';
    final postOwnerId = widget.post['userId'] ?? '';
    
    // Only show actions if current user is post owner
    if (currentUserId != postOwnerId && !postOwnerId.isEmpty) {
      return [];
    }
    
    return [
      PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') {
            _showEditDialog();
          } else if (value == 'delete') {
            _showDeleteConfirm();
          }
        },
        itemBuilder: (BuildContext context) => [
          const PopupMenuItem<String>(
            value: 'edit',
            child: Text('Edit'),
          ),
          const PopupMenuItem<String>(
            value: 'delete',
            child: Text('Delete'),
          ),
        ],
      ),
    ];
  }

  void _showEditDialog() {
    final currentCaption = widget.post['caption'] ?? '';
    final currentLocation = widget.post['location'] ?? '';
    final captionController = TextEditingController(text: currentCaption);
    final locationController = TextEditingController(text: currentLocation);
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Post'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: captionController,
                  decoration: const InputDecoration(
                    labelText: 'Caption',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  enabled: !isUpdating,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !isUpdating,
                ),
              ],
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
                        final response = await widget.apiService.post('/posts/update', {
                          'postId': widget.post['id'],
                          'userId': userId,
                          'caption': captionController.text,
                          'location': locationController.text,
                        });

                        if (response['success'] == true) {
                          widget.post['caption'] = captionController.text;
                          widget.post['location'] = locationController.text;
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Post updated successfully!'),
                                backgroundColor: Color(0xFF66BB6A),
                              ),
                            );
                            this.setState(() {});
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

  void _showDeleteConfirm() {
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
                final response = await widget.apiService.post('/posts/delete', {
                  'postId': widget.post['id'],
                  'userId': userId,
                });

                if (response['success'] == true) {
                  if (mounted) {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close post details
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post deleted successfully!'),
                        backgroundColor: Color(0xFF66BB6A),
                      ),
                    );
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
        actions: _buildAppBarActions(),
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
