import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';
import '../anonymous/anonymous_screen.dart';

// ============================================================
// CHAT SCREEN - شاشة الدردشة
// ============================================================

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ✅ بيانات المحادثات الوهمية
  final List<Map<String, dynamic>> chats = [
    {
      'id': 1,
      'name_ar': 'أحمد محمد',
      'name_en': 'Ahmed Mohammed',
      'lastMessage_ar': 'مرحباً! كيف حالك؟',
      'lastMessage_en': 'Hello! How are you?',
      'time': '10:30',
      'unread': 2,
      'avatar': 'A',
      'online': true,
    },
    {
      'id': 2,
      'name_ar': 'سارة علي',
      'name_en': 'Sara Ali',
      'lastMessage_ar': 'شكراً لك 🙏',
      'lastMessage_en': 'Thank you 🙏',
      'time': '09:15',
      'unread': 0,
      'avatar': 'S',
      'online': false,
    },
    {
      'id': 3,
      'name_ar': 'نور خالد',
      'name_en': 'Noor Khaled',
      'lastMessage_ar': 'هل أنت جاهز للامتحان؟',
      'lastMessage_en': 'Are you ready for the exam?',
      'time': 'أمس',
      'unread': 5,
      'avatar': 'N',
      'online': true,
    },
    {
      'id': 4,
      'name_ar': 'يزن عمر',
      'name_en': 'Yazen Omar',
      'lastMessage_ar': 'تم رفع الملخص 📚',
      'lastMessage_en': 'The summary is uploaded 📚',
      'time': 'أمس',
      'unread': 0,
      'avatar': 'Y',
      'online': false,
    },
    {
      'id': 5,
      'name_ar': 'ليلى أحمد',
      'name_en': 'Laila Ahmed',
      'lastMessage_ar': 'سأرسل لك الملف قريباً',
      'lastMessage_en': 'I will send you the file soon',
      'time': 'أمس',
      'unread': 3,
      'avatar': 'L',
      'online': true,
    },
  ];

  void _showSearchDialog() {
    final controller = TextEditingController();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.isArabic;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final q = controller.text.trim().toLowerCase();
          final results = chats.where((chat) {
            final name = '${chat['name_ar']} ${chat['name_en']}'.toLowerCase();
            final message = '${chat['lastMessage_ar']} ${chat['lastMessage_en']}'.toLowerCase();
            return q.isEmpty || name.contains(q) || message.contains(q);
          }).toList();
          return AlertDialog(
            title: Text(isArabic ? '🔎 بحث في الدردشة' : '🔎 Search chats'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: isArabic ? 'اسم أو رسالة' : 'Name or message',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 240,
                    child: results.isEmpty
                        ? Center(child: Text(isArabic ? 'لا توجد نتائج' : 'No results'))
                        : ListView(
                            children: results.map((chat) {
                              final name = isArabic ? chat['name_ar'] : chat['name_en'];
                              return ListTile(
                                leading: CircleAvatar(child: Text('$name'[0])),
                                title: Text(name),
                                subtitle: Text(isArabic ? chat['lastMessage_ar'] : chat['lastMessage_en']),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _ChatDetailScreen(
                                        chatName: name,
                                        chatId: chat['id'],
                                        isArabic: isArabic,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _startNewChat() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.isArabic;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? '💬 محادثة جديدة' : '💬 New chat'),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: chats.map((chat) {
              final name = isArabic ? chat['name_ar'] : chat['name_en'];
              return ListTile(
                leading: CircleAvatar(child: Text('$name'[0])),
                title: Text(name),
                onTap: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ChatDetailScreen(
                        chatName: name,
                        chatId: chat['id'],
                        isArabic: isArabic,
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FAF9),
        appBar: AppBar(
          title: Text(
            isArabic ? '💬 الدردشة' : '💬 Chat',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnonymousScreen()),
                );
              },
              icon: const Icon(Icons.visibility_off_rounded),
              tooltip: isArabic ? 'الرسائل المجهولة' : 'Anonymous Messages',
            ),
            IconButton(
              onPressed: _showSearchDialog,
              icon: const Icon(Icons.search_rounded),
              tooltip: isArabic ? 'بحث في الدردشة' : 'Search chats',
            ),
          ],
        ),
        body: chats.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isArabic
                          ? '📭 لا توجد محادثات'
                          : '📭 No chats',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isArabic
                          ? 'ابدأ محادثة جديدة الآن'
                          : 'Start a new chat now',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final bool isUnread = (chat['unread'] ?? 0) > 0;
                  final bool isOnline = chat['online'] ?? false;
                  final String name = isArabic ? chat['name_ar'] : chat['name_en'];
                  final String lastMessage = isArabic
                      ? chat['lastMessage_ar']
                      : chat['lastMessage_en'];

                  return GestureDetector(
                    onTap: () {
                      // ✅ فتح شاشة المحادثة الفردية
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ChatDetailScreen(
                            chatName: name,
                            chatId: chat['id'],
                            isArabic: isArabic,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha(25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // ==============================================
                          // صورة المستخدم
                          // ==============================================
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFFDDF6F3),
                                child: Text(
                                  chat['avatar'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF087F78),
                                  ),
                                ),
                              ),
                              if (isOnline)
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: BorderDirectional(
                                        top: BorderSide(color: Colors.white, width: 2),
                                        bottom: BorderSide(color: Colors.white, width: 2),
                                        start: BorderSide(color: Colors.white, width: 2),
                                        end: BorderSide(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // ==============================================
                          // معلومات المحادثة
                          // ==============================================
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: isUnread
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      chat['time'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lastMessage,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isUnread
                                              ? Colors.black87
                                              : Colors.grey.shade600,
                                          fontWeight: isUnread
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF12AFA5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${chat['unread']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _startNewChat,
          backgroundColor: const Color(0xFF12AFA5),
          foregroundColor: Colors.white,
          child: const Icon(Icons.chat_rounded),
        ),
      ),
    );
  }
}

// ============================================================
// CHAT DETAIL SCREEN - شاشة المحادثة الفردية
// ============================================================

class _ChatDetailScreen extends StatefulWidget {
  final String chatName;
  final int chatId;
  final bool isArabic;

  const _ChatDetailScreen({
    required this.chatName,
    required this.chatId,
    required this.isArabic,
  });

  @override
  State<_ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<_ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    // ✅ رسائل وهمية
    _messages.addAll([
      {
        'text_ar': 'مرحباً! كيف حالك؟',
        'text_en': 'Hello! How are you?',
        'isMe': false,
        'time': '10:30',
      },
      {
        'text_ar': 'أنا بخير، الحمد لله. وأنت؟',
        'text_en': "I'm fine, thank you. And you?",
        'isMe': true,
        'time': '10:31',
      },
      {
        'text_ar': 'هل أنت جاهز للامتحان؟',
        'text_en': 'Are you ready for the exam?',
        'isMe': false,
        'time': '10:32',
      },
      {
        'text_ar': 'نعم، أنا أدرس الآن 📚',
        'text_en': 'Yes, I am studying now 📚',
        'isMe': true,
        'time': '10:33',
      },
    ]);
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'text_ar': _messageController.text.trim(),
        'text_en': _messageController.text.trim(),
        'isMe': true,
        'time': DateTime.now().toLocal().toString().substring(11, 16),
      });
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.isArabic;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFDDF6F3),
                child: Icon(
                  Icons.person_rounded,
                  color: Color(0xFF087F78),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.chatName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Column(
          children: [
            // ==============================================
            // قائمة الرسائل
            // ==============================================
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isMe = message['isMe'] ?? false;
                  final text = isArabic ? message['text_ar'] : message['text_en'];

                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF12AFA5)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            text,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message['time'],
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? Colors.white70
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ==============================================
            // حقل إرسال الرسالة
            // ==============================================
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(25),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'اكتب رسالة...' : 'Type a message...',
                        filled: true,
                        fillColor: const Color(0xFFF5FAF9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF12AFA5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}