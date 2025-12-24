import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadConversations();
    // Her 2 saniyede bir konuşmalar listesini yenile
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadConversationsWithoutLoading();
    });
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.email ?? '';

      final response = await _apiService.get('/messaging/conversations/$userId');

      if (response['success'] == true) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(response['conversations'] ?? []);
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

      final response = await _apiService.get('/messaging/conversations/$userId');

      if (response['success'] == true && mounted) {
        final newConversations = List<Map<String, dynamic>>.from(response['conversations'] ?? []);
        // Konuşma sayısı veya sıra değişirse güncelle
        if (newConversations.length != _conversations.length ||
            (newConversations.isNotEmpty && _conversations.isNotEmpty &&
             newConversations[0]['lastMessageTime'] != _conversations[0]['lastMessageTime'])) {
          setState(() {
            _conversations = newConversations;
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing conversations: $e');
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
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message_outlined, size: 80, color: Colors.grey[300]),
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
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final currentUserId = authService.currentUser?.email ?? '';

                    // Diğer kullanıcı kimdir?
                    final otherUserId =
                        conversation['user1'] == currentUserId ? conversation['user2'] : conversation['user1'];
                    final otherUserName =
                        conversation['user1'] == currentUserId ? conversation['user2Name'] : conversation['user1Name'];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF9DB8E8),
                          child: Text(
                            otherUserName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          otherUserName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
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
                        trailing: Text(
                          _formatTime(DateTime.parse(conversation['lastMessageTime'])),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatDetailScreen(
                                conversationId: conversation['id'],
                                otherUserId: otherUserId,
                                otherUserName: otherUserName,
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
  final String currentUserId;
  final String currentUserName;
  final VoidCallback onMessagesUpdated;

  const ChatDetailScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.currentUserId,
    required this.currentUserName,
    required this.onMessagesUpdated,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Her 2 saniyede bir mesajları yenile (gerçek zamanlı görünüm)
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
          _messages = List<Map<String, dynamic>>.from(response['messages'] ?? []);
        });
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
        final newMessages = List<Map<String, dynamic>>.from(response['messages'] ?? []);
        // Sadece yeni mesaj varsa güncelle
        if (newMessages.length != _messages.length) {
          setState(() {
            _messages = newMessages;
          });
        }
      }
    } catch (e) {
      // Sessiz hata - refresh timer devam etsin
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

  @override
  void dispose() {
    _messageController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.otherUserName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isSent = message['senderId'] == widget.currentUserId;

                            return Align(
                              alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSent ? const Color(0xFF9DB8E8) : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: isSent
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message['text'],
                                      style: TextStyle(
                                        color: isSent ? Colors.white : Colors.black87,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatMessageTime(
                                          DateTime.parse(message['timestamp'])),
                                      style: TextStyle(
                                        color:
                                            isSent ? Colors.white70 : Colors.grey[600],
                                        fontSize: 11,
                                      ),
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
                          onSubmitted: _isSending ? null : (_) => _sendMessage(),
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
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white, size: 20),
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
