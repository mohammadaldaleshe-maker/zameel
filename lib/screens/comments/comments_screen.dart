import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

// ============================================================
// COMMENTS SCREEN
// ============================================================

class CommentsScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const CommentsScreen({
    super.key,
    required this.post,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();

  // بيانات وهمية للتعليقات (مترجمة)
  final List<Map<String, String>> _comments = [
    {
      'name_ar': 'أحمد محمد', 'name_en': 'Ahmad Mohammad',
      'department_ar': 'علم الحاسوب', 'department_en': 'Computer Science',
      'time_ar': 'منذ 5 دقائق', 'time_en': '5 min ago',
      'text_ar': 'شرح رائع جداً، استفدت كثيراً 🙏', 'text_en': 'Great explanation, I benefited a lot 🙏',
    },
    {
      'name_ar': 'سارة علي', 'name_en': 'Sara Ali',
      'department_ar': 'هندسة البرمجيات', 'department_en': 'Software Engineering',
      'time_ar': 'منذ 12 دقيقة', 'time_en': '12 min ago',
      'text_ar': 'هل يمكنك توضيح النقطة الثانية أكثر؟', 'text_en': 'Can you explain the second point more?',
    },
    {
      'name_ar': 'يزن عمر', 'name_en': 'Yazan Omar',
      'department_ar': 'نظم المعلومات', 'department_en': 'Information Systems',
      'time_ar': 'منذ 20 دقيقة', 'time_en': '20 min ago',
      'text_ar': 'شكراً على المشاركة 🌟', 'text_en': 'Thanks for sharing 🌟',
    },
  ];

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.isArabic;

    setState(() {
      _comments.insert(0, {
        'name_ar': 'أنت', 'name_en': 'You',
        'department_ar': widget.post['department_ar'] ?? 'طالب', 
        'department_en': widget.post['department_en'] ?? 'Student',
        'time_ar': 'الآن', 'time_en': 'Now',
        'text_ar': text, 'text_en': text,
      });
      _commentController.clear();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
            isArabic ? 'التعليقات' : 'Comments',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(isArabic ? 'إغلاق' : 'Close'),
            ),
          ],
        ),
        body: Column(
          children: [
            // ====================================================
            // المنشور الأصلي
            // ====================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFDDF6F3),
                        child: Icon(
                          Icons.person,
                          color: Color(0xFF0B9F95),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic 
                                ? (widget.post['name_ar'] ?? 'مستخدم')
                                : (widget.post['name_en'] ?? 'User'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              isArabic 
                                ? (widget.post['department_ar'] ?? '')
                                : (widget.post['department_en'] ?? ''),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isArabic 
                      ? (widget.post['text_ar'] ?? '')
                      : (widget.post['text_en'] ?? ''),
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),

            // ====================================================
            // قائمة التعليقات
            // ====================================================
            Expanded(
              child: _comments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isArabic 
                              ? 'لا توجد تعليقات بعد\nكن أول من يعلق!'
                              : 'No comments yet\nBe the first to comment!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return _CommentCard(comment: comment);
                      },
                    ),
            ),

            // ====================================================
            // مربع كتابة التعليق
            // ====================================================
            Container(
              padding: const EdgeInsets.all(12),
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
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'اكتب تعليقك...' : 'Write a comment...',
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
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF18D3C3),
                    child: IconButton(
                      onPressed: _addComment,
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
// COMMENT CARD
// ============================================================

class _CommentCard extends StatelessWidget {
  final Map<String, String> comment;

  const _CommentCard({
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFDDF6F3),
                child: Icon(
                  Icons.person,
                  size: 18,
                  color: Color(0xFF0B9F95),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? (comment['name_ar'] ?? 'مستخدم') : (comment['name_en'] ?? 'User'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      isArabic 
                        ? '${comment['department_ar'] ?? ''} • ${comment['time_ar'] ?? ''}'
                        : '${comment['department_en'] ?? ''} • ${comment['time_en'] ?? ''}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? (comment['text_ar'] ?? '') : (comment['text_en'] ?? ''),
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}