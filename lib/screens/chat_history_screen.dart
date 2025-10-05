import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart'; // افترض وجود ملف chat_screen.dart

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  static const Color primaryColor = Color(0xFF5A189A); // لون أساسي موحد

  // دالة لبدء محادثة جديدة
  Future<String> _startNewChat(User user) async {
    final newChatRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .add({
      'title': 'محادثة جديدة',
      'last_message_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    });
    return newChatRef.id;
  }

  void _navigateToChat(BuildContext context, String chatId, String chatTitle) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ChatScreen(chatId: chatId, chatTitle: chatTitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color darkBackground = Color(0xFF1E1E1E);

    if (user == null) {
      return const Center(child: Text("الرجاء تسجيل الدخول."));
    }

    return Scaffold(
      backgroundColor: isDarkMode ? darkBackground : Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('تاريخ المحادثات'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // زر محادثة جديدة
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: () async {
              final newChatId = await _startNewChat(user);
              _navigateToChat(context, newChatId, 'محادثة جديدة');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم فتح صفحة الإعدادات')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('chats')
            .orderBy('last_message_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'لا توجد محادثات سابقة. ابدأ محادثة جديدة! 💬',
                style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
              ),
            );
          }

          final chats = snapshot.data!.docs;
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'محادثة غير معنونة';
              final timestamp = data['last_message_at'] as Timestamp?;

              return ListTile(
                leading: Icon(Icons.chat_bubble_outline, color: primaryColor.withOpacity(0.7)),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  timestamp != null
                      ? 'آخر رسالة: ${_formatTimestamp(timestamp)}'
                      : 'لا توجد رسائل',
                  style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  _navigateToChat(context, chat.id, title);
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')} - ${dateTime.day}/${dateTime.month}';
  }
}