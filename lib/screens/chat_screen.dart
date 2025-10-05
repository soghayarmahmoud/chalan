import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
// import 'package:flutter_tts/flutter_tts.dart'; // معطلة: لإضافة ميزة القراءة الصوتية (TTS)، يجب إلغاء تعليقها وإضافتها في pubspec.yaml

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;

  const ChatScreen({super.key, required this.chatId, required this.chatTitle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late User _currentUser;
  
  final FlutterTts flutterTts = FlutterTts(); // معطلة: لإلغاء التعليق عند استخدام TTS

  final _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: 'AIzaSyAxeEDPI_o9M24XA5nblfqXtSfix0C01nQ', 
  );

  late ChatSession _chat; 
  bool _isLoadingHistory = true;

  // الألوان الموحدة
  static const Color primaryColor = Color(0xFF5A189A);
  static const Color lightBackground = Color(0xFFF7F7F7);
  static const Color darkBackground = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
    _initializeChatSession();
    // _initTts(); // معطلة
  }

  // تهيئة جلسة الدردشة وتحميل التاريخ
  void _initializeChatSession() async {
    // 1. تحميل الرسائل السابقة
    final pastMessagesSnapshot = await _firestore
        .collection('users')
        .doc(_currentUser.uid)
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .get();

    // 2. تحويل رسائل Firestore إلى كائنات Content لـ Gemini
    List<Content> history = [];
    for (var doc in pastMessagesSnapshot.docs) {
      final data = doc.data();
      final text = data['text'] as String;
      final isUser = data['is_user'] as bool;
      
      // التعديل هنا: استخدام دالة Content.fromParts
      // Content.new يأخذ الآن وسيطتين موضِعيتين، أو يمكنك استخدام دالة مساعدة
      final role = isUser ? 'user' : 'model';

      if (text.isNotEmpty) {
        // الحل: استخدام Content.fromParts أو إنشاء Content مع الوسيطات الموضعية
        // البنية الجديدة: Content(role, [Part1, Part2, ...])
        history.add(Content(role, [TextPart(text)]));
      }
    }

    // 3. بدء الجلسة باستخدام السجل (History)
    _chat = _model.startChat(history: history);
    setState(() {
      _isLoadingHistory = false;
    });
  }

  // دالة TTS (معطلة)
  void _initTts() {
    flutterTts.setLanguage("ar-SA"); 
  }
  
  String _cleanGeminiText(String text) {
    return text
        .replaceAll(RegExp(r'\*\*|__'), '') 
        .replaceAll(RegExp(r'^\s*#+\s*'), '')
        .trim();
  }
  
  void _deleteMessage(String messageId) async {
    try {
      await _firestore
          .collection('users')
          .doc(_currentUser.uid)
          .collection('chats')
          .doc(widget.chatId) 
          .collection('messages')
          .doc(messageId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الرسالة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: ${e.toString()}')),
        );
      }
    }
  }

  // دالة TTS (معطلة)
  void _speak(String text) async {
    await flutterTts.speak(text);
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoadingHistory) return;

    _messageController.clear();
    final chatRef = _firestore.collection('users').doc(_currentUser.uid).collection('chats').doc(widget.chatId);

    // 1. تحديث عنوان المحادثة بأول رسالة
    if (widget.chatTitle == 'محادثة جديدة') {
      await chatRef.update({'title': text.length > 30 ? '${text.substring(0, 30)}...' : text});
    }
    
    // 2. تحديث وقت آخر رسالة
    await chatRef.update({'last_message_at': FieldValue.serverTimestamp()});

    // 3. حفظ رسالة المستخدم
    final userMessageRef = await chatRef.collection('messages').add({
      'text': text,
      'senderId': _currentUser.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'is_user': true,
    });

    try {
      final response = await _chat.sendMessage(Content.text(text));

      if (response.text != null) {
        final geminiText = _cleanGeminiText(response.text!);
        // 5. حفظ رسالة المساعد
        await chatRef.collection('messages').add({
          'text': geminiText,
          'senderId': 'ai_assistant_id',
          'timestamp': FieldValue.serverTimestamp(),
          'is_user': false,
          'has_image': response.text!.contains('[Image]') ? true : false, 
        });
      }
    } catch (e) {
      userMessageRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    // flutterTts.stop(); // معطلة
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final chatBackground = isDarkMode ? darkBackground : lightBackground;

    return Scaffold(
      backgroundColor: chatBackground,
      appBar: AppBar(
        title: Text(widget.chatTitle.length > 25 ? '${widget.chatTitle.substring(0, 25)}...' : widget.chatTitle), 
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
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
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [darkBackground, const Color(0xFF282828)]
                    : [lightBackground, const Color(0xFFEFEFEF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          if (_isLoadingHistory)
            const Center(child: CircularProgressIndicator(color: primaryColor))
          else
            Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(_currentUser.uid)
                        .collection('chats')
                        .doc(widget.chatId) 
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                         return const Center(child: CircularProgressIndicator(color: primaryColor));
                      }

                      final messages = snapshot.data!.docs;
                      if (messages.isEmpty) {
                         return Center(
                            child: Text(
                              'ابدأ المحادثة الآن! 🤖',
                              style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
                            ),
                          );
                      }
                      
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12.0),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final data = message.data() as Map<String, dynamic>;
                          final isUserMessage = data['is_user'] as bool;
                          final messageId = message.id;

                          return MessageBubble(
                            text: data['text'],
                            isUserMessage: isUserMessage,
                            primaryColor: primaryColor,
                            messageId: messageId,
                            onSpeak: _speak, // معطلة
                            onDelete: _deleteMessage, 
                            isImage: data['has_image'] ?? false, 
                          );
                        },
                      );
                    },
                  ),
                ),
                _buildMessageInput(primaryColor, isDarkMode),
              ],
            ),
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

// ----------------------------------------------------------------------
// -------------------- Message Bubble Component --------------------------
// ----------------------------------------------------------------------

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUserMessage;
  final Color primaryColor;
  final String messageId;
  final bool isImage;
  final Function(String) onDelete;
  final Function(String)? onSpeak; // إذا كانت TTS مفعلة

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUserMessage,
    required this.primaryColor,
    required this.messageId,
    required this.onDelete,
    this.onSpeak,
    this.isImage = false,
  });

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الرسالة')),
    );
  }

  void _downloadImage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('بدء تنزيل الصورة... (يتطلب تنفيذ منطق التنزيل)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color userBubbleColor = primaryColor;
    final Color aiBubbleColor = isDarkMode ? const Color(0xFF424242) : const Color(0xFFE0E0E0);
    final Color userTextColor = Colors.white;
    final Color aiTextColor = isDarkMode ? Colors.white : Colors.black;
    final Color actionIconColor = isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;

    return Column(
      crossAxisAlignment: isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: isUserMessage
              ? () {
                  _showUserActions(context, onDelete, messageId);
                }
              : null,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.only(top: 6.0, bottom: 2.0, left: 8.0, right: 8.0),
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
                height: 1.4,
              ),
            ),
          ),
        ),

        if (!isUserMessage)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionChip(
                  icon: Icons.copy,
                  onTap: () => _copyToClipboard(context),
                  color: actionIconColor,
                ),
                const SizedBox(width: 4),

                // زر القراءة (TTS)
                if (onSpeak != null)
                  _buildActionChip(
                    icon: Icons.volume_up,
                    onTap: () => onSpeak!(text),
                    color: actionIconColor,
                  ),
                const SizedBox(width: 4),

                // زر التنزيل
                if (isImage)
                  _buildActionChip(
                    icon: Icons.download,
                    onTap: () => _downloadImage(context),
                    color: actionIconColor,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionChip({required IconData icon, required VoidCallback onTap, required Color color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Icon(
          icon,
          size: 18,
          color: color,
        ),
      ),
    );
  }

  void _showUserActions(BuildContext context, Function(String) onDelete, String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.copy, color: primaryColor),
              title: const Text('نسخ الرسالة'),
              onTap: () {
                _copyToClipboard(context);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('حذف الرسالة'),
              onTap: () {
                onDelete(messageId);
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('إلغاء'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}