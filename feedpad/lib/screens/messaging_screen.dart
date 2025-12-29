import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../animations/route_animations.dart';
import 'other_user_profile_screen.dart';
import 'profile_screen.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

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

  void _openUserProfileFromConversation(
      String userId, String name, String? username, String? profileImage) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.email ?? '';
    final resolvedUsername = (username != null && username.isNotEmpty)
        ? username
        : (userId.contains('@') ? userId.split('@').first : 'username');

    if (userId == currentUserId && currentUserId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const ProfileScreen(showAppBar: true)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtherUserProfileScreen(
            user: {
              'id': userId,
              'email': userId,
              'name': name,
              'username': resolvedUsername,
              'bio': '🐾 Pet lover',
              'profileImage': profileImage ?? '',
            },
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadConversationsWithoutLoading();
    });
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.email ?? '';

      final response =
          await _apiService.get('/messaging/conversations/$userId');

      if (response['success'] == true) {
        setState(() {
          _conversations =
              List<Map<String, dynamic>>.from(response['conversations'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadConversationsWithoutLoading() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.email ?? '';

      final response =
          await _apiService.get('/messaging/conversations/$userId');

      if (response['success'] == true && mounted) {
        final newConversations =
            List<Map<String, dynamic>>.from(response['conversations'] ?? []);
        if (newConversations.length != _conversations.length ||
            (newConversations.isNotEmpty &&
                _conversations.isNotEmpty &&
                newConversations[0]['lastMessageTime'] !=
                    _conversations[0]['lastMessageTime'])) {
          setState(() {
            _conversations = newConversations;
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing conversations: $e');
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.email ?? '';

      final response = await _apiService.delete(
        '/messaging/conversation/$conversationId?userId=$userId',
      );

      if (response['success'] == true) {
        await _loadConversations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation deleted'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _hideConversation(String conversationId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.email ?? '';

      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete chat?'),
              content: const Text(
                  'This chat and all messages will be permanently deleted.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed) return;

      final response = await _apiService.delete(
        '/messaging/conversation/$conversationId?userId=$userId',
      );

      if (response['success'] == true) {
        await _loadConversations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation deleted'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message_outlined,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a new conversation!',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = _conversations[index];
                    final authService =
                        Provider.of<AuthService>(context, listen: false);
                    final currentUserId = authService.currentUser?.email ?? '';

                    final otherUserId = conversation['user1'] == currentUserId
                        ? conversation['user2']
                        : conversation['user1'];
                    final otherUserName = conversation['user1'] == currentUserId
                        ? conversation['user2Name']
                        : conversation['user1Name'];
                    final otherUsername = conversation['user1'] == currentUserId
                        ? conversation['user2Username']
                        : conversation['user1Username'];
                    final otherUserProfileImage =
                        conversation['user1'] == currentUserId
                            ? conversation['user2ProfileImage']
                            : conversation['user1ProfileImage'];
                    final currentUserProfileImage =
                        conversation['user1'] == currentUserId
                            ? conversation['user1ProfileImage']
                            : conversation['user2ProfileImage'];

                    return Dismissible(
                      key: Key(conversation['id']),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        _deleteConversation(conversation['id']);
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: GestureDetector(
                            onTap: () => _openUserProfileFromConversation(
                              otherUserId,
                              otherUserName,
                              otherUsername,
                              otherUserProfileImage,
                            ),
                            child: CircleAvatar(
                              backgroundColor: const Color(0xFF9DB8E8),
                              backgroundImage: otherUserProfileImage != null &&
                                      otherUserProfileImage.isNotEmpty
                                  ? _getImageProvider(otherUserProfileImage)
                                  : null,
                              child: otherUserProfileImage == null ||
                                      otherUserProfileImage.isEmpty
                                  ? Text(
                                      otherUserName[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          title: GestureDetector(
                            onTap: () => _openUserProfileFromConversation(
                              otherUserId,
                              otherUserName,
                              otherUsername,
                              otherUserProfileImage,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  otherUserName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                Text(
                                  '@${otherUsername ?? 'username'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF90A4AE),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          subtitle: Text(
                            conversation['lastMessage'] ?? 'No messages',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          trailing: SizedBox(
                            width: 120,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTime(DateTime.parse(
                                      conversation['lastMessageTime'])),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  onPressed: () {
                                    _hideConversation(conversation['id']);
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              SlideRightRoute(
                                page: ChatDetailScreen(
                                  conversationId: conversation['id'],
                                  otherUserId: otherUserId,
                                  otherUserName: otherUserName,
                                  otherUsername: otherUsername ??
                                      (otherUserId.contains('@')
                                          ? otherUserId.split('@').first
                                          : ''),
                                  otherUserProfileImage:
                                      otherUserProfileImage ?? '',
                                  currentUserProfileImage:
                                      currentUserProfileImage ?? '',
                                  currentUserId: currentUserId,
                                  currentUserName: currentUser?.name ?? 'You',
                                  onMessagesUpdated: () {
                                    _loadConversations();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUsername;
  final String otherUserProfileImage;
  final String currentUserId;
  final String currentUserName;
  final String currentUserProfileImage;
  final VoidCallback onMessagesUpdated;

  const ChatDetailScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUsername,
    required this.otherUserProfileImage,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserProfileImage,
    required this.onMessagesUpdated,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  Timer? _refreshTimer;

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

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadMessagesWithoutLoading();
    });
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get(
        '/messaging/conversation/${widget.currentUserId}/${widget.otherUserId}',
      );

      if (response['success'] == true) {
        setState(() {
          _messages =
              List<Map<String, dynamic>>.from(response['messages'] ?? []);
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessagesWithoutLoading() async {
    try {
      final response = await _apiService.get(
        '/messaging/conversation/${widget.currentUserId}/${widget.otherUserId}',
      );

      if (response['success'] == true && mounted) {
        final newMessages =
            List<Map<String, dynamic>>.from(response['messages'] ?? []);
        if (newMessages.length != _messages.length) {
          setState(() {
            _messages = newMessages;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error refreshing messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final response = await _apiService.post('/messaging/send', {
        'senderId': widget.currentUserId,
        'senderName': widget.currentUserName,
        'recipientId': widget.otherUserId,
        'recipientName': widget.otherUserName,
        'text': _messageController.text,
      });

      if (response['success'] == true) {
        _messageController.clear();
        await _loadMessages();
        widget.onMessagesUpdated();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      final response = await _apiService.delete(
        '/messaging/message/${widget.conversationId}/$messageId?userId=${widget.currentUserId}',
      );

      if (response['success'] == true) {
        await _loadMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message deleted'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final headerUsername = widget.otherUsername.isNotEmpty
        ? widget.otherUsername
        : (widget.otherUserId.contains('@')
            ? widget.otherUserId.split('@').first
            : widget.otherUserName.replaceAll(' ', '').toLowerCase());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE3F2FD),
              backgroundImage: widget.otherUserProfileImage.isNotEmpty
                  ? _getImageProvider(widget.otherUserProfileImage)
                  : null,
              child: widget.otherUserProfileImage.isEmpty
                  ? Text(
                      widget.otherUserName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF1E88E5),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '@$headerUsername',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF9DB8E8),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages yet. Start a conversation!',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isSent =
                                message['senderId'] == widget.currentUserId;
                            final senderName = message['senderName'] ??
                                (isSent
                                    ? widget.currentUserName
                                    : widget.otherUserName);
                            final senderUsername = message['senderUsername'] ??
                                (message['senderId'] is String &&
                                        (message['senderId'] as String)
                                            .contains('@')
                                    ? (message['senderId'] as String)
                                        .split('@')
                                        .first
                                    : isSent
                                        ? widget.currentUserId.split('@').first
                                        : widget.otherUserId.split('@').first);
                            final senderProfileImage =
                                message['senderProfileImage'] ??
                                    (isSent
                                        ? widget.currentUserProfileImage
                                        : widget.otherUserProfileImage);

                            return GestureDetector(
                              onLongPress: isSent
                                  ? () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (context) => Container(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red),
                                                title: const Text(
                                                    'Delete Message'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _deleteMessage(message['id']);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: isSent
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isSent)
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            const Color(0xFF9DB8E8),
                                        backgroundImage:
                                            senderProfileImage.isNotEmpty
                                                ? _getImageProvider(
                                                    senderProfileImage)
                                                : null,
                                        child: senderProfileImage.isEmpty
                                            ? Text(
                                                senderName.isNotEmpty
                                                    ? senderName[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                    if (!isSent) const SizedBox(width: 8),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment: isSent
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            crossAxisAlignment: isSent
                                                ? CrossAxisAlignment.end
                                                : CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                senderName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Color(0xFF2C3E50),
                                                ),
                                              ),
                                              Text(
                                                '@$senderUsername',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF90A4AE),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Align(
                                            alignment: isSent
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isSent
                                                    ? const Color(0xFF9DB8E8)
                                                    : Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: isSent
                                                    ? CrossAxisAlignment.end
                                                    : CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    message['text'],
                                                    style: TextStyle(
                                                      color: isSent
                                                          ? Colors.white
                                                          : Colors.black87,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatMessageTime(
                                                        DateTime.parse(message[
                                                            'timestamp'])),
                                                    style: TextStyle(
                                                      color: isSent
                                                          ? Colors.white70
                                                          : Colors.grey[600],
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSent) const SizedBox(width: 8),
                                    if (isSent)
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            const Color(0xFF9DB8E8),
                                        backgroundImage:
                                            senderProfileImage.isNotEmpty
                                                ? _getImageProvider(
                                                    senderProfileImage)
                                                : null,
                                        child: senderProfileImage.isEmpty
                                            ? Text(
                                                senderName.isNotEmpty
                                                    ? senderName[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !_isSending,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(0xFFBBDEFB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(0xFFBBDEFB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(0xFF9DB8E8),
                                width: 2,
                              ),
                            ),
                          ),
                          onSubmitted:
                              _isSending ? null : (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: const Color(0xFF9DB8E8),
                        child: IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send,
                                  color: Colors.white, size: 20),
                          onPressed: _isSending ? null : _sendMessage,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
