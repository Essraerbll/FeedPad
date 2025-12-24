import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

// Separate dialog widgets to avoid StatefulBuilder issues
class CreatePostDialog extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onPostCreated;

  const CreatePostDialog({
    super.key,
    required this.apiService,
    required this.onPostCreated,
  });

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageName;

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty && result.files.first.bytes != null) {
        final bytes = result.files.first.bytes!;
        
        // Check file size (max 2MB for safety)
        if (bytes.length > 2 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Resim çok büyük! Lütfen 2MB\'dan küçük bir resim seçin.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
            _imageName = result.files.first.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim seçme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createPost() async {
    if (_captionController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen bir başlık yazınız'),
            backgroundColor: Color(0xFF64B5F6),
          ),
        );
      }
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.email;

    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User bilgisi bulunamadı'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    String? imageDataUrl;
    if (_imageBytes != null) {
      final ext = (_imageName?.split('.').last ?? 'png').toLowerCase();
      final mime = ext == 'jpg' ? 'jpeg' : ext;
      imageDataUrl = 'data:image/$mime;base64,${base64Encode(_imageBytes!)}';
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paylaşılıyor...'),
            backgroundColor: Color(0xFF64B5F6),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final response = await widget.apiService.post('/posts/create', {
        'userId': userId,
        'userName': authService.currentUser?.name ?? 'User',
        'caption': _captionController.text,
        'location': _locationController.text.isNotEmpty ? _locationController.text : '',
        'imageUrl': imageDataUrl ?? '',
      });

      if (response['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post başarıyla paylaşıldı!'),
              backgroundColor: Color(0xFF66BB6A),
            ),
          );
          widget.onPostCreated();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${response['message'] ?? 'Bilinmeyen hata'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Post creation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paylaşma hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF0F8FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.add_photo_alternate, color: Color(0xFF64B5F6)),
          SizedBox(width: 8),
          Text(
            'Post Oluştur',
            style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF90CAF9), width: 2),
                ),
                child: Center(
                  child: _imageBytes == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 48, color: Color(0xFF64B5F6)),
                            SizedBox(height: 8),
                            Text('Fotoğraf Ekle', style: TextStyle(color: Color(0xFF1976D2))),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _imageBytes!,
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
                _imageName ?? 'JPG/PNG seçin',
                style: const TextStyle(color: Color(0xFF546E7A), fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Başlık',
                labelStyle: const TextStyle(color: Color(0xFF1976D2)),
                hintText: 'Bunu paylaş...',
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
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Konum (opsiyonel)',
                labelStyle: const TextStyle(color: Color(0xFF1976D2)),
                hintText: 'Konum ekle...',
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
          onPressed: _createPost,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF64B5F6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Paylaş', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class EditProfileDialog extends StatefulWidget {
  final ApiService apiService;
  final String currentBio;
  final String? currentProfileImage;
  final VoidCallback onProfileUpdated;

  const EditProfileDialog({
    super.key,
    required this.apiService,
    required this.currentBio,
    this.currentProfileImage,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  Uint8List? _newProfileImageBytes;
  String? _newProfileImageDataUrl;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _nameController = TextEditingController(
      text: authService.currentUser?.name ?? '',
    );
    _bioController = TextEditingController(text: widget.currentBio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

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

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          // Check file size (max 2MB for safety)
          if (file.bytes!.length > 2 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Resim çok büyük! Lütfen 2MB\'dan küçük bir resim seçin.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }
          
          if (mounted) {
            final ext = (file.name.split('.').last).toLowerCase();
            final mime = ext == 'jpg' || ext == 'jpeg' ? 'jpeg' : 'png';
            
            setState(() {
              _newProfileImageBytes = file.bytes;
              _newProfileImageDataUrl = 'data:image/$mime;base64,${base64Encode(file.bytes!)}';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim seçme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.email;

    final profileImageToSend = _newProfileImageDataUrl ?? widget.currentProfileImage;
    
    debugPrint('=== Save Profile Debug ===');
    debugPrint('User ID: $userId');
    debugPrint('Name: ${_nameController.text}');
    debugPrint('Bio: ${_bioController.text}');
    debugPrint('New Profile Image: ${_newProfileImageDataUrl != null ? "YES (${_newProfileImageDataUrl!.length} chars)" : "NO"}');
    debugPrint('Current Profile Image: ${widget.currentProfileImage != null ? "YES (${widget.currentProfileImage!.length} chars)" : "NO"}');
    debugPrint('Sending Profile Image: ${profileImageToSend != null ? "YES (${profileImageToSend.length} chars)" : "NO"}');

    try {
      final requestBody = {
        'userId': userId,
        'name': _nameController.text.isEmpty ? null : _nameController.text,
        'bio': _bioController.text,
        'profileImage': profileImageToSend,
      };
      
      debugPrint('Request Body Keys: ${requestBody.keys.toList()}');
      
      final response = await widget.apiService.put('/posts/profile', requestBody);
      
      debugPrint('Response: $response');

      if (response['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated!'),
              backgroundColor: Color(0xFF66BB6A),
            ),
          );
          await authService.getCurrentUser();
          widget.onProfileUpdated();
        }
      } else {
        throw Exception(response['message'] ?? 'Update failed');
      }
    } catch (e) {
      debugPrint('Profile update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    return AlertDialog(
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
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF64B5F6),
                  backgroundImage: _newProfileImageBytes != null
                      ? MemoryImage(_newProfileImageBytes!)
                      : _getImageProvider(widget.currentProfileImage),
                  child: _newProfileImageBytes == null && (widget.currentProfileImage == null || widget.currentProfileImage!.isEmpty)
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
                      onPressed: _pickImage,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
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
            TextField(
              controller: _bioController,
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
          onPressed: _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF64B5F6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
