import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';

// ============================================================
// GRADUATION BOOK SCREEN
// ============================================================

class GraduationBookScreen extends StatefulWidget {
  final String studentName;
  final String university;
  final String major;
  final String graduationYear;

  const GraduationBookScreen({
    super.key,
    required this.studentName,
    required this.university,
    required this.major,
    required this.graduationYear,
  });

  @override
  State<GraduationBookScreen> createState() => _GraduationBookScreenState();
}

class _GraduationBookScreenState extends State<GraduationBookScreen> {
  bool isPublic = true;
  List<Map<String, dynamic>> messages = [];

  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    // بيانات وهمية للرسائل
    messages = [
      {
        'id': 1,
        'sender': 'أحمد محمد',
        'senderImage': null,
        'message': 'مبروك تخرجك يا صديقي! 🎉 كان معك وقت جميل في الجامعة. أتمنى لك مستقبل مشرق.',
        'date': '2024-06-15',
        'time': '14:30',
        'isAnonymous': false,
      },
      {
        'id': 2,
        'sender': 'مجهول',
        'senderImage': null,
        'message': 'أنت قدوة للجميع، نجاحك كان مستحقاً. كل التوفيق في حياتك المهنية 💪',
        'date': '2024-06-14',
        'time': '22:15',
        'isAnonymous': true,
      },
      {
        'id': 3,
        'sender': 'سارة علي',
        'senderImage': null,
        'message': 'فخور بك وبإنجازاتك. كنت زميلاً رائعاً وسأفتقد أيام الجامعة معك ❤️',
        'date': '2024-06-14',
        'time': '18:45',
        'isAnonymous': false,
      },
      {
        'id': 4,
        'sender': 'مجهول',
        'senderImage': null,
        'message': 'نتمنى لك حظاً سعيداً في حياتك الجديدة. لا تنسنا 🤍',
        'date': '2024-06-13',
        'time': '10:20',
        'isAnonymous': true,
      },
    ];
  }

  void _addMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      messages.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch,
        'sender': _isAnonymous ? 'مجهول' : 'أنت',
        'senderImage': null,
        'message': _messageController.text.trim(),
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'time': DateTime.now().toIso8601String().substring(11, 16),
        'isAnonymous': _isAnonymous,
      });
      _messageController.clear();
    });
  }

  bool _isAnonymous = false;

  void _shareBook() {
    // مشاركة رابط دفتر الخريج
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔗 تم نسخ رابط دفتر الخريج!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '📖 دفتر الخريج',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _shareBook,
              icon: const Icon(Icons.share_rounded),
              tooltip: 'مشاركة الدفتر',
            ),
          ],
        ),
        body: Column(
          children: [
            // ====================================================
            // HEADER - معلومات الخريج
            // ====================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF12AFA5),
                    Color(0xFF087F78),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // ==============================================
                  // الصورة الرمزية
                  // ==============================================
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 45,
                      color: Color(0xFF12AFA5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.studentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🎓 ${widget.major}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '🏫 ${widget.university} • ${widget.graduationYear}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ==============================================
                  // إعدادات الخصوصية
                  // ==============================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.visibility_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isArabic ? 'دفتر عام' : 'Public Book',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Switch(
                        value: isPublic,
                        onChanged: (value) {
                          setState(() {
                            isPublic = value;
                          });
                        },
                        activeColor: Colors.white,
                        inactiveThumbColor: Colors.grey.shade400,
                      ),
                      const Icon(
                        Icons.visibility_off_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ====================================================
            // COUNTER - عدد الرسائل
            // ====================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${messages.length} ${isArabic ? 'رسالة' : 'Messages'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF087F78),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isAnonymous = !_isAnonymous;
                      });
                    },
                    icon: Icon(
                      _isAnonymous
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: _isAnonymous ? Colors.orange : Colors.grey,
                    ),
                    label: Text(
                      _isAnonymous
                          ? isArabic ? 'مرسل مجهول' : 'Anonymous'
                          : isArabic ? 'مرسل باسمي' : 'With Name',
                      style: TextStyle(
                        color: _isAnonymous ? Colors.orange : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 8),

            // ====================================================
            // MESSAGES LIST
            // ====================================================
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'لا توجد رسائل بعد',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'كن أول من يكتب رسالة تهنئة 🎉',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isAnonymous = message['isAnonymous'] ?? false;
                        return _MessageCard(
                          message: message,
                          isAnonymous: isAnonymous,
                          onDelete: () {
                            setState(() {
                              messages.removeAt(index);
                            });
                          },
                        );
                      },
                    ),
            ),

            // ====================================================
            // MESSAGE INPUT
            // ====================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: isArabic
                            ? 'اكتب رسالة تهنئة...'
                            : 'Write a congratulatory message...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _addMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF12AFA5),
                    child: IconButton(
                      onPressed: _addMessage,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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

// ============================================================
// MESSAGE CARD
// ============================================================

class _MessageCard extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isAnonymous;
  final VoidCallback onDelete;

  const _MessageCard({
    required this.message,
    required this.isAnonymous,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isAnonymous ? Colors.orange.withOpacity(0.3) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==============================================
          // HEADER
          // ==============================================
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isAnonymous
                    ? Colors.orange.withOpacity(0.2)
                    : const Color(0xFFDDF6F3),
                child: Icon(
                  isAnonymous
                      ? Icons.visibility_off_rounded
                      : Icons.person_rounded,
                  size: 20,
                  color: isAnonymous
                      ? Colors.orange
                      : const Color(0xFF087F78),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAnonymous ? 'مجهول' : message['sender'],
                      style: TextStyle(
                        fontWeight: isAnonymous ? FontWeight.normal : FontWeight.bold,
                        fontSize: 14,
                        color: isAnonymous ? Colors.orange : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${message['date']} • ${message['time']}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) {
                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: AlertDialog(
                          title: const Text('حذف الرسالة'),
                          content: const Text('هل أنت متأكد من حذف هذه الرسالة؟'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                              },
                              child: const Text('إلغاء'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                onDelete();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ==============================================
          // MESSAGE
          // ==============================================
          Text(
            message['message'],
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}