import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'other_user_profile_screen.dart';
import 'messaging_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  // Örnek kullanıcı listesi
  late List<Map<String, dynamic>> _allUsers;
  late Set<String> _followingUsers;

  @override
  void initState() {
    super.initState();
    _initializeUsers();
  }

  void _initializeUsers() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserEmail = authService.currentUser?.email ?? '';

    _allUsers = [
      {
        'id': 'user_1',
        'email': 'sarah.johnson@example.com',
        'name': 'Sarah Johnson',
        'bio': '🐾 Dog lover | Photography enthusiast',
        'profileImage': null,
        'postsCount': 12,
        'followersCount': 245,
      },
      {
        'id': 'user_2',
        'email': 'mike.anderson@example.com',
        'name': 'Mike Anderson',
        'bio': '🐈 Cat lover | Pet trainer',
        'profileImage': null,
        'postsCount': 28,
        'followersCount': 512,
      },
      {
        'id': 'user_3',
        'email': 'emily.brown@example.com',
        'name': 'Emily Brown',
        'bio': '🦜 Bird enthusiast | Travel lover',
        'profileImage': null,
        'postsCount': 45,
        'followersCount': 1200,
      },
      {
        'id': 'user_4',
        'email': 'john.smith@example.com',
        'name': 'John Smith',
        'bio': '🐹 Small pet expert | Veterinarian',
        'profileImage': null,
        'postsCount': 67,
        'followersCount': 1800,
      },
      {
        'id': 'user_5',
        'email': 'lisa.martin@example.com',
        'name': 'Lisa Martin',
        'bio': '🐴 Equestrian | Horse lover',
        'profileImage': null,
        'postsCount': 34,
        'followersCount': 892,
      },
    ];

    // Mevcut kullanıcıyı listeden çıkar
    _allUsers.removeWhere((user) => user['email'] == currentUserEmail);

    // Takip edilen kullanıcılar
    _followingUsers = {'user_2', 'user_4'};
  }

  void _toggleFollow(String userId) {
    setState(() {
      if (_followingUsers.contains(userId)) {
        _followingUsers.remove(userId);
      } else {
        _followingUsers.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F1FA),
      body: _allUsers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No users to discover',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _allUsers.length,
              itemBuilder: (context, index) {
                final user = _allUsers[index];
                final isFollowing = _followingUsers.contains(user['id']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF64B5F6),
                              backgroundImage: user['profileImage'] != null
                                  ? NetworkImage(user['profileImage'])
                                  : null,
                              child: user['profileImage'] == null
                                  ? Text(
                                      user['name'][0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
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
                                    user['name'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user['bio'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF546E7A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _toggleFollow(user['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing
                                    ? Colors.grey[300]
                                    : const Color(0xFF64B5F6),
                                foregroundColor: isFollowing
                                    ? Colors.black87
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Stats
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  user['postsCount'].toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64B5F6),
                                  ),
                                ),
                                const Text(
                                  'Posts',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  user['followersCount'].toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64B5F6),
                                  ),
                                ),
                                const Text(
                                  'Followers',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          OtherUserProfileScreen(user: user),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF64B5F6),
                                  side: const BorderSide(
                                    color: Color(0xFF64B5F6),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('View Profile'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isFollowing)
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final authService = Provider.of<AuthService>(context, listen: false);
                                    final currentUserId = authService.currentUser?.email ?? '';
                                    final currentUserName = authService.currentUser?.name ?? 'You';
                                    
                                    // ChatDetailScreen'i direkt aç (messaging_screen.dart içindeki widget)
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) {
                                          // ChatDetailScreen import edilmeli
                                          return ChatDetailScreen(
                                            conversationId: [currentUserId, user['email']].join(':'),
                                            otherUserId: user['email'],
                                            otherUserName: user['name'],
                                            currentUserId: currentUserId,
                                            currentUserName: currentUserName,
                                            onMessagesUpdated: () {},
                                          );
                                        },
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF64B5F6),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Message'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
