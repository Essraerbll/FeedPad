import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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
      
      // Load posts
      try {
        final postsResponse = await _apiService.get('/posts/user/$userId');
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
    final TextEditingController captionController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    Uint8List? imageBytes;
    String? imageName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
        backgroundColor: const Color(0xFFF0F8FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_photo_alternate, color: Color(0xFF64B5F6)),
            SizedBox(width: 8),
            Text(
              'Create Post',
              style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image picker / preview
              GestureDetector(
                onTap: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    withData: true,
                  );
                  if (result != null && result.files.isNotEmpty) {
                    setStateDialog(() {
                      imageBytes = result.files.first.bytes;
                      imageName = result.files.first.name;
                    });
                  }
                },
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF90CAF9), width: 2),
                  ),
                  child: Center(
                    child: imageBytes == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 48, color: Color(0xFF64B5F6)),
                              SizedBox(height: 8),
                              Text('Add Photo', style: TextStyle(color: Color(0xFF1976D2))),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              imageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  imageName ?? 'JPG/PNG seçin',
                  style: const TextStyle(color: Color(0xFF546E7A), fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              // Caption
              TextField(
                controller: captionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Caption',
                  labelStyle: const TextStyle(color: Color(0xFF1976D2)),
                  hintText: 'Write something about this...',
                  prefixIcon: const Icon(Icons.edit, color: Color(0xFF64B5F6)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Location
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: 'Location (optional)',
                  labelStyle: const TextStyle(color: Color(0xFF1976D2)),
                  hintText: 'Add location...',
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF64B5F6)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF1976D2))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (captionController.text.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please write a caption'),
                      backgroundColor: Color(0xFF64B5F6),
                    ),
                  );
                }
                return;
              }
              
              final authService = Provider.of<AuthService>(context, listen: false);
              final userId = authService.currentUser?.email;
              String? imageDataUrl;
              if (imageBytes != null) {
                final ext = (imageName?.split('.').last ?? 'png').toLowerCase();
                final mime = ext == 'jpg' ? 'jpeg' : ext;
                imageDataUrl = 'data:image/$mime;base64,${base64Encode(imageBytes!)}';
              }
              
              try {
                final response = await _apiService.post('/posts/create', {
                  'userId': userId,
                  'caption': captionController.text,
                  'location': locationController.text,
                  'imageUrl': imageDataUrl,
                });
                
                if (response['success']) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post created!'),
                        backgroundColor: Color(0xFF66BB6A),
                      ),
                    );
                  }
                  _loadUserData(); // Reload
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
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64B5F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController bioController = TextEditingController(text: _bio);
    final authService = Provider.of<AuthService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF0F8FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF64B5F6)),
            SizedBox(width: 8),
            Text(
              'Edit Profile',
              style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Image
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF64B5F6),
                    backgroundImage: _profileImageUrl != null 
                        ? NetworkImage(_profileImageUrl!) 
                        : null,
                    child: _profileImageUrl == null 
                        ? const Icon(Icons.pets, size: 50, color: Colors.white)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1976D2),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Image picker coming soon!'),
                              backgroundColor: Color(0xFF64B5F6),
                            ),
                          );
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Name
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: const TextStyle(color: Color(0xFF1976D2)),
                  hintText: authService.currentUser?.name ?? 'Your name',
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF64B5F6)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Bio
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  labelStyle: const TextStyle(color: Color(0xFF1976D2)),
                  hintText: 'Tell us about yourself...',
                  prefixIcon: const Icon(Icons.info_outline, color: Color(0xFF64B5F6)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF1976D2))),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = authService.currentUser?.email;
              
              try {
                await _apiService.put('/posts/profile', {
                  'userId': userId,
                  'name': nameController.text.isEmpty ? null : nameController.text,
                  'bio': bioController.text,
                });
                
                setState(() {
                  if (bioController.text.isNotEmpty) {
                    _bio = bioController.text;
                  }
                });
                // Refresh user data so UI reflects changes
                await authService.getCurrentUser();
                await _loadUserData();
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated!'),
                      backgroundColor: Color(0xFF66BB6A),
                    ),
                  );
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
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64B5F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF64B5F6)))
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
                              colors: [Color(0xFF64B5F6), Color(0xFF90CAF9), Color(0xFF42A5F5)],
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
                              backgroundImage: _profileImageUrl != null 
                                  ? NetworkImage(_profileImageUrl!) 
                                  : null,
                              child: _profileImageUrl == null 
                                  ? const Icon(Icons.pets, size: 45, color: Color(0xFF64B5F6))
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
                          const SizedBox(height: 4),
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
            // Posts Grid
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
                : SliverPadding(
                    padding: const EdgeInsets.all(2.0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 3,
                        crossAxisSpacing: 3,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildPostTile(_posts[index]),
                        childCount: _posts.length,
                      ),
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

  Widget _buildPostTile(Map<String, dynamic> post) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final userName = auth.currentUser?.name ?? 'You';
    final caption = post['caption'] ?? '';

    return GestureDetector(
      onTap: () {
        // TODO: Show post detail
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(
                Icons.pets,
                size: 40,
                color: const Color(0xFF64B5F6).withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
          ),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.favorite, color: Color(0xFF64B5F6), size: 14),
              const SizedBox(width: 4),
              Text(
                '${post['likes'] ?? 0}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

