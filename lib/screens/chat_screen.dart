import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

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

  // 1. استخدام dotenv لإخفاء مفتاح API
  final _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey:'AIzaSyAxeEDPI_o9M24XA5nblfqXtSfix0C01nQ', // تأكد من إضافة المفتاح هنا أو في ملف .env
  );

  late final ChatSession _chat;

  @override
  void initState() {
    super.initState();
    _chat = _model.startChat();
    // تأكد من أن المستخدم الحالي غير فارغ قبل البدء
    if (_auth.currentUser == null) {
      // يمكنك هنا إضافة منطق لتوجيه المستخدم لصفحة تسجيل الدخول إذا لم يكن مسجلاً
      throw Exception("User is not signed in.");
    }
    _currentUser = _auth.currentUser!;
  }

  // دالة مساعدة لتنظيف نص Gemini من علامات Markdown البسيطة
  String _cleanGeminiText(String text) {
    // إزالة علامات الـ Markdown للخط العريض (**), (##), (*), وغير ذلك
    return text
        .replaceAll(RegExp(r'\*\*|__'), '') // إزالة علامات الخط العريض
        .replaceAll(RegExp(r'^\s*#+\s*'), '') // إزالة علامات العناوين في بداية السطر
        .replaceAll(RegExp(r'\*'), '•') // تحويل علامات القائمة النقطية إلى نقطة
        .trim();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    // 1. إرسال رسالة المستخدم إلى Firestore
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

    // 2. الحصول على رد Gemini
    try {
      final response = await _chat.sendMessage(Content.text(text));

      if (response.text != null) {
        // 3. تنظيف نص الرد قبل حفظه وعرضه
        final geminiText = _cleanGeminiText(response.text!);

        await _firestore
            .collection('users')
            .doc(_currentUser.uid)
            .collection('messages')
            .add({
          'text': geminiText, // حفظ النص المنظف
          'senderId': 'ai_assistant_id',
          'timestamp': FieldValue.serverTimestamp(),
          'is_user': false,
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 2. ألوان جديدة وجذابة
    const Color primaryColor = Color(0xFF5A189A); // لون بنفسجي غامق جذاب
    const Color lightBackground = Color(0xFFF7F7F7); // خلفية فاتحة ناعمة
    const Color darkBackground = Color(0xFF1E1E1E); // خلفية داكنة راقية
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? darkBackground : lightBackground,
      appBar: AppBar(
        title: const Text('AI Chat'),
        // لون شريط التطبيق
        backgroundColor: primaryColor,
        foregroundColor: Colors.white, // لون الأيقونات والنصوص في شريط التطبيق
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
                      'ابدأ المحادثة الآن! 🤖',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final data = message.data() as Map<String, dynamic>;
                    final isUserMessage = data['is_user'] as bool;

                    return MessageBubble(
                      text: data['text'],
                      isUserMessage: isUserMessage,
                      primaryColor: primaryColor,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(primaryColor, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildMessageInput(Color primaryColor, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF282828) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: isDarkMode ? const Color(0xFF333333) : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 4.0),
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
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
  final Color primaryColor;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUserMessage,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // ألوان الفقاعة
    final Color userBubbleColor = primaryColor;
    final Color aiBubbleColor = isDarkMode ? const Color(0xFF424242) : const Color(0xFFE0E0E0);
    final Color userTextColor = Colors.white;
    final Color aiTextColor = isDarkMode ? Colors.white : Colors.black;

    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // تحديد أقصى عرض
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isUserMessage ? userBubbleColor : aiBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20.0),
            topRight: const Radius.circular(20.0),
            bottomLeft: isUserMessage ? const Radius.circular(20.0) : const Radius.circular(5.0),
            bottomRight: isUserMessage ? const Radius.circular(5.0) : const Radius.circular(20.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.15),
              spreadRadius: 0,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUserMessage ? userTextColor : aiTextColor,
            fontSize: 15.0,
            height: 1.4, // مسافة بين الأسطر لتحسين القراءة
          ),
        ),
      ),
    );
  }
}