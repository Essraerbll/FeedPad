import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  // Sohbet listesi - konuşma verilerini kalıcı olarak saklıyoruz
  late List<Map<String, dynamic>> _conversations;

  @override
  void initState() {
    super.initState();
    _initializeConversations();
  }

  void _initializeConversations() {
    _conversations = [
      {
        'id': 'conv_1',
        'userName': 'Sarah Johnson',
        'userImage': null,
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'unread': true,
        'messages': [
          {
            'id': 'msg_1',
            'sender': 'Sarah Johnson',
            'text': 'Hi! Love your pet photos!',
            'timestamp': DateTime.now().subtract(const Duration(hours: 3)),
            'isSent': false,
          },
          {
            'id': 'msg_2',
            'sender': 'You',
            'text': 'Thanks! Your photos are amazing too!',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 50)),
            'isSent': true,
          },
          {
            'id': 'msg_3',
            'sender': 'Sarah Johnson',
            'text': 'Cute pet photo!',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
            'isSent': false,
          },
        ],
      },
      {
        'id': 'conv_2',
        'userName': 'Mike Anderson',
        'userImage': null,
        'timestamp': DateTime.now().subtract(const Duration(days: 1)),
        'unread': false,
        'messages': [
          {
            'id': 'msg_1',
            'sender': 'Mike Anderson',
            'text': 'Hey, how are you?',
            'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 2)),
            'isSent': false,
          },
          {
            'id': 'msg_2',
            'sender': 'You',
            'text': 'Good! How about you?',
            'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 50)),
            'isSent': true,
          },
          {
            'id': 'msg_3',
            'sender': 'Mike Anderson',
            'text': 'Thanks for the tip!',
            'timestamp': DateTime.now().subtract(const Duration(days: 1)),
            'isSent': false,
          },
        ],
      },
      {
        'id': 'conv_3',
        'userName': 'Emily Brown',
        'userImage': null,
        'timestamp': DateTime.now().subtract(const Duration(days: 2)),
        'unread': false,
        'messages': [
          {
            'id': 'msg_1',
            'sender': 'Emily Brown',
            'text': 'Are you coming tomorrow?',
            'timestamp': DateTime.now().subtract(const Duration(days: 2, hours: 3)),
            'isSent': false,
          },
          {
            'id': 'msg_2',
            'sender': 'You',
            'text': 'Yes, I will be there!',
            'timestamp': DateTime.now().subtract(const Duration(days: 2, hours: 2, minutes: 45)),
            'isSent': true,
          },
          {
            'id': 'msg_3',
            'sender': 'Emily Brown',
            'text': 'See you tomorrow',
            'timestamp': DateTime.now().subtract(const Duration(days: 2)),
            'isSent': false,
          },
        ],
      },
    ];
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
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        backgroundColor: const Color(0xFF64B5F6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _conversations.isEmpty
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
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF64B5F6),
                    backgroundImage: conversation['userImage'] != null
                        ? NetworkImage(conversation['userImage'])
                        : null,
                    child: conversation['userImage'] == null
                        ? Text(
                            conversation['userName'][0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    conversation['userName'],
                    style: TextStyle(
                      fontWeight: conversation['unread']
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                  subtitle: Text(
                    conversation['messages'].isNotEmpty
                        ? conversation['messages'].last['text']
                        : 'No messages',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: conversation['unread']
                          ? const Color(0xFF546E7A)
                          : Colors.grey,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(conversation['timestamp']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (conversation['unread'])
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFF64B5F6),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(
                          conversation: conversation,
                          currentUserName:
                              currentUser?.name ?? 'You',
                          onMessagesUpdated: (updatedConversation) {
                            setState(() {
                              final index = _conversations
                                  .indexWhere((c) => c['id'] == updatedConversation['id']);
                              if (index != -1) {
                                _conversations[index] = updatedConversation;
                              }
                            });
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
  final Map<String, dynamic> conversation;
  final String currentUserName;
  final Function(Map<String, dynamic>)? onMessagesUpdated;

  const ChatDetailScreen({
    Key? key,
    required this.conversation,
    required this.currentUserName,
    this.onMessagesUpdated,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  late List<Map<String, dynamic>> _messages;
  late String _otherUserName;

  // Örnek otomatik yanıtlar
  final List<String> _autoReplies = [
    'That sounds great!',
    'I agree with you!',
    'Thanks for the message!',
    'How was your day?',
    'Sounds good to me!',
    'Let me know!',
    'Absolutely!',
    'Nice!',
    'See you soon!',
    'Take care!',
  ];

  @override
  void initState() {
    super.initState();
    _otherUserName = widget.conversation['userName'];
    _messages = List<Map<String, dynamic>>.from(widget.conversation['messages'] ?? []);
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) return;

    setState(() {
      // Kullanıcının mesajını ekle
      _messages.add({
        'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
        'sender': widget.currentUserName,
        'text': _messageController.text,
        'timestamp': DateTime.now(),
        'isSent': true,
      });

      final userMessage = _messageController.text;
      _messageController.clear();

      // Otomatik yanıt gönder (biraz gecikme ile)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _messages.add({
              'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
              'sender': _otherUserName,
              'text': _autoReplies[DateTime.now().microsecond % _autoReplies.length],
              'timestamp': DateTime.now(),
              'isSent': false,
            });
          });
        }
      });
    });

    // Konuşmayı güncelle
    widget.conversation['messages'] = _messages;
    widget.conversation['timestamp'] = DateTime.now();
    widget.conversation['unread'] = false;
    widget.onMessagesUpdated?.call(widget.conversation);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversation['userName']),
        elevation: 0,
        backgroundColor: const Color(0xFF64B5F6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isSent = message['isSent'] == true;

                return Align(
                  alignment:
                      isSent ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSent
                          ? const Color(0xFF64B5F6)
                          : Colors.grey[300],
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
                          _formatMessageTime(message['timestamp']),
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
                          color: Color(0xFF64B5F6),
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF64B5F6),
                  child: IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _sendMessage,
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

  String _formatMessageTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
