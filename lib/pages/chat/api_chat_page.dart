import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../models/user_role.dart';
import '../../utils/colors.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String currentUserName;
  final UserRole currentUserRole;
  final String otherUserName;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
    required this.otherUserName,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _messages = [];
  Timer? _pollingTimer;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    // Start polling every 3 seconds for new messages
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchMessages(isPolling: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool isPolling = false}) async {
    try {
      if (!isPolling && _messages.isEmpty && !kIsWeb) {
        // Load from local DB first for instant display
        final localMsgs = await _dbService.getLocalMessages(widget.chatId);
        if (localMsgs.isNotEmpty && mounted) {
          setState(() {
            _messages =
                localMsgs.map((m) => Map<String, dynamic>.from(m)).toList();
            _isLoading = false;
          });
          _scrollToBottom();
        }
      }

      final messages = await _apiService.apiGetMessages(widget.chatId);
      if (mounted) {
        // Mark as read if there are new messages not from me
        final hasNewMessagesFromOther = messages.any((m) => m['senderId'] != widget.currentUserId && m['read'] == 0);
        if (hasNewMessagesFromOther) {
          _apiService.apiMarkMessagesAsRead(widget.chatId, widget.currentUserId);
        }

        setState(() {
          if (messages.isNotEmpty) {
            // Smart merge to prevent flickering and disappearing messages
            final Map<String, Map<String, dynamic>> messageMap = {};

            // Add existing messages (preserving optimistic ones)
            for (var m in _messages) {
              final key = m['id'] ?? "${m['senderId']}_${m['timestamp']}";
              messageMap[key.toString()] = m;
            }

            // Sync with server messages (server is source of truth)
            for (var m in messages) {
              final key = m['id'] ?? "${m['senderId']}_${m['timestamp']}";
              messageMap[key.toString()] = m;
            }

            _messages = messageMap.values.toList();
            _messages.sort((a, b) => (a['timestamp'] as num).compareTo(b['timestamp'] as num));
          }
          _isLoading = false;
        });

        // Save to local DB for persistence (Skip on Web)
        if (!kIsWeb && messages.isNotEmpty) {
          for (var msg in messages) {
            final msgToSave = {
              'id': (msg['id'] ?? msg['timestamp']).toString(),
              'chatId': widget.chatId,
              'senderId': (msg['senderId'] ?? msg['senderid']).toString(),
              'senderName': (msg['senderName'] ?? msg['sendername'] ?? 'Unknown').toString(),
              'text': (msg['text'] ?? '').toString(),
              'timestamp': msg['timestamp'] ?? msg['time'] ?? 0,
            };
            await _dbService.saveLocalMessage(msgToSave);
          }
        }

        if (!isPolling) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Error fetching messages: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Optimistic update
    final tempMsg = {
      'senderId': widget.currentUserId,
      'senderName': widget.currentUserName,
      'text': text,
      'timestamp': timestamp,
      'status': 'sending',
    };

    setState(() {
      _messages.add(tempMsg);
    });
    _scrollToBottom();

    // Save locally first (Skip on Web)
    if (!kIsWeb) {
      final msgToSave = Map<String, dynamic>.from(tempMsg);
      msgToSave['chatId'] = widget.chatId;
      await _dbService.saveLocalMessage(msgToSave);
      await _dbService.updateLocalChatLastMessage(widget.chatId, text, timestamp);
    }

    final result = await _apiService.apiSendMessage(
      chatId: widget.chatId,
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      text: text,
    );

    if (result['success'] == true) {
      // Update the optimistic message with server data
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['timestamp'] == timestamp && m['senderId'] == widget.currentUserId);
          if (index != -1) {
            _messages[index]['id'] = result['messageId'];
            _messages[index]['status'] = 'sent';
          }
        });
      }
    }

    // Delay slightly before polling to allow server to sync
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _fetchMessages(isPolling: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: RoleColors.getPrimaryColor(widget.currentUserRole),
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Start a conversation!'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          // Normalize senderId regardless of casing
                          final senderId = message['senderId'] ?? message['senderid'];
                          final isMe = senderId.toString() == widget.currentUserId.toString();

                          return _buildMessageBubble(message, isMe);
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final status = message['status'] ?? 'sent';
    final timestamp = message['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(message['timestamp'] as int)
        : DateTime.now();
    final timeStr = "${timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12}:${timestamp.minute.toString().padLeft(2, '0')} ${timestamp.hour >= 12 ? 'PM' : 'AM'}";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? RoleColors.getPrimaryColor(widget.currentUserRole) : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message['senderName'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ),
            Text(
              message['text'] ?? '',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 9,
                    color: isMe ? Colors.white70 : Colors.black45,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(message),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(Map<String, dynamic> message) {
    final status = message['status'] ?? 'sent';
    final isRead = message['read'] == 1 || message['read'] == true;

    if (isRead) {
      return const Icon(Icons.done_all, size: 14, color: Colors.blueAccent);
    }

    switch (status) {
      case 'sending':
        return const Icon(Icons.access_time, size: 12, color: Colors.white70);
      case 'sent':
        return const Icon(Icons.done, size: 12, color: Colors.white70);
      default:
        return const Icon(Icons.done_all, size: 12, color: Colors.white70);
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: RoleColors.getPrimaryColor(widget.currentUserRole),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
