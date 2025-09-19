import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    await _firestore
        .collection('users')
        .doc(_currentUser.uid)
        .collection('messages')
        .add({
      'text': text,
      'senderId': _currentUser.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'is_user': true,
    });

    await Future.delayed(const Duration(seconds: 1));
    await _firestore
        .collection('users')
        .doc(_currentUser.uid)
        .collection('messages')
        .add({
      'text': 'Hello! I am your AI assistant. How can I help you today?',
      'senderId': 'ai_assistant_id',
      'timestamp': FieldValue.serverTimestamp(),
      'is_user': false,
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF171717)
          : Colors.grey[100],
      appBar: AppBar(
        title: const Text('AI Chat'),
        // تخفيف لون الـ AppBar
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.85),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_currentUser.uid)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.5),
                      ),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final data = message.data() as Map<String, dynamic>;
                    final isUserMessage = data['is_user'] as bool;

                    return MessageBubble(
                      text: data['text'],
                      isUserMessage: isUserMessage,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.grey[200],
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white12
                : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.black54,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUserMessage;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUserMessage,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        // تعديل تصميم فقاعة الرسالة (هنا حدث التغيير)
        decoration: BoxDecoration(
          // إضافة تدرج لوني لفقاعة المستخدم بدلاً من اللون الصلب
          gradient: isUserMessage
              ? LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.9),
                    Theme.of(context).primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUserMessage
              ? null // اللون أصبح من التدرج
              : (isDarkMode ? const Color(0xFF333333) : Colors.grey[300]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16.0),
            topRight: const Radius.circular(16.0),
            bottomLeft: isUserMessage ? const Radius.circular(16.0) : const Radius.circular(0),
            bottomRight: isUserMessage ? const Radius.circular(0) : const Radius.circular(16.0),
          ),
          // إضافة ظل خفيف للفقاعة لإعطائها عمقًا
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUserMessage
                ? Colors.white
                : (isDarkMode ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }
}