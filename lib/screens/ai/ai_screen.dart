import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';
import '../../services_ai.dart';

// ============================================================
// ZAMEEL AI SCREEN
// ============================================================

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  int selectedTab = 0; // 0 = مساعد, 1 = تلخيص, 2 = شرح

  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _textController = TextEditingController();

  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text_ar': 'مرحباً! أنا مساعد Zameel الذكي. كيف يمكنني مساعدتك اليوم؟ 🤖',
      'text_en': 'Hello! I am Zameel AI Assistant. How can I help you today? 🤖',
      'time': '10:00',
    },
  ];

  final List<Map<String, dynamic>> _sampleQuestions = [
    {'ar': 'ما هي أفضل ممارسات البرمجة؟', 'en': 'What are the best programming practices?'},
    {'ar': 'كيف أدرس للامتحان بفعالية؟', 'en': 'How to study effectively for exams?'},
    {'ar': 'ما هو الذكاء الاصطناعي؟', 'en': 'What is Artificial Intelligence?'},
    {'ar': 'كيف أكتب سيرة ذاتية جيدة؟', 'en': 'How to write a good CV?'},
  ];

  bool _isLoading = false;
  String? _summary;
  String? _explanation;

  Future<void> _sendMessage() async {
    final text = _questionController.text.trim();
    if (text.isEmpty || _isLoading) return;
    setState(() {
      _messages.add({'isUser': true, 'text_ar': text, 'text_en': text, 'time': DateTime.now().toIso8601String().substring(11, 16)});
      _questionController.clear();
      _isLoading = true;
    });
    try {
      final answer = await ZameelAIService.ask(text, mode: 'assistant', language: isArabicLanguage(context) ? 'ar' : 'en');
      if (!mounted) return;
      setState(() => _messages.add({'isUser': false, 'text_ar': answer, 'text_en': answer, 'time': DateTime.now().toIso8601String().substring(11, 16)}));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add({'isUser': false, 'text_ar': 'تعذر الاتصال بزميل AI الآن. تأكد من نشر Edge Function وضبط OPENAI_API_KEY.', 'text_en': 'Zameel AI is unavailable. Please verify the Edge Function and OPENAI_API_KEY.', 'time': DateTime.now().toIso8601String().substring(11, 16)}));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  bool isArabicLanguage(BuildContext context) => Provider.of<LanguageProvider>(context, listen: false).isArabic;

  String _getAIResponse(String question, bool isArabic) {
    final q = question.toLowerCase();
    if (q.contains('برمجة') || q.contains('programming') || q.contains('كود') || q.contains('code')) {
      return isArabic
          ? '💻 البرمجة هي عملية كتابة الأكواد لتطوير البرامج والتطبيقات. أفضل الممارسات تشمل: كتابة كود نظيف، استخدام التسميات المناسبة، التعليق على الكود، واختبار الكود بشكل مستمر. هل لديك سؤال محدد؟'
          : '💻 Programming is the process of writing code to develop software and applications. Best practices include: writing clean code, using proper naming, commenting code, and continuous testing. Do you have a specific question?';
    } else if (q.contains('امتحان') || q.contains('study') || q.contains('دراسة')) {
      return isArabic
          ? '📚 للدراسة بفعالية: قسم وقتك، استخدم تقنية بومودورو، قم بمراجعة المواد بانتظام، حل الأسئلة السابقة، وخذ فترات راحة منتظمة. هل تريد نصائح إضافية؟'
          : '📚 To study effectively: divide your time, use the Pomodoro technique, review materials regularly, solve past questions, and take regular breaks. Do you want additional tips?';
    } else if (q.contains('ذكاء اصطناعي') || q.contains('artificial intelligence') || q.contains('ai')) {
      return isArabic
          ? '🤖 الذكاء الاصطناعي هو مجال يهدف إلى إنشاء أنظمة قادرة على محاكاة الذكاء البشري. يشمل تعلم الآلة، الشبكات العصبية، ومعالجة اللغة الطبيعية. هل تريد معرفة المزيد عن مجال معين؟'
          : '🤖 Artificial Intelligence is a field that aims to create systems capable of simulating human intelligence. It includes machine learning, neural networks, and natural language processing. Do you want to know more about a specific area?';
    } else if (q.contains('سيرة ذاتية') || q.contains('cv') || q.contains('resume')) {
      return isArabic
          ? '📄 سيرة ذاتية جيدة يجب أن تحتوي على: معلومات شخصية، ملخص مهني، الخبرات العملية، المهارات، الشهادات، والمراجع. احرص على تخصيصها لكل وظيفة. هل تحتاج مساعدة في جزء معين؟'
          : '📄 A good CV should contain: personal information, professional summary, work experience, skills, certifications, and references. Make sure to customize it for each job. Do you need help with a specific part?';
    } else {
      return isArabic
          ? '🤔 سؤال ممتاز! دعني أفكر في ذلك... أنا هنا لمساعدتك في كل ما يتعلق بحياتك الجامعية والدراسية. هل يمكنك توضيح سؤالك أكثر؟'
          : '🤔 Excellent question! Let me think about that... I am here to help you with everything related to your university and academic life. Could you clarify your question further?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '🤖 Zameel AI' : '🤖 Zameel AI',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // ====================================================
            // TABS
            // ====================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _AITabButton(
                    text: isArabic ? '💬 مساعد' : '💬 Assistant',
                    isSelected: selectedTab == 0,
                    onTap: () {
                      setState(() {
                        selectedTab = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _AITabButton(
                    text: isArabic ? '📝 تلخيص' : '📝 Summary',
                    isSelected: selectedTab == 1,
                    onTap: () {
                      setState(() {
                        selectedTab = 1;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _AITabButton(
                    text: isArabic ? '📖 شرح' : '📖 Explain',
                    isSelected: selectedTab == 2,
                    onTap: () {
                      setState(() {
                        selectedTab = 2;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ====================================================
            // CONTENT
            // ====================================================
            Expanded(
              child: selectedTab == 0
                  ? _buildAssistantTab(isArabic)
                  : selectedTab == 1
                      ? _buildSummaryTab(isArabic)
                      : _buildExplainTab(isArabic),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ASSISTANT TAB (المساعد)
  // ============================================================

  Widget _buildAssistantTab(bool isArabic) {
    return Column(
      children: [
        // ==============================================
        // CHAT MESSAGES
        // ==============================================
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isUser = message['isUser'];
              return _MessageBubble(
                message: isArabic ? message['text_ar'] : message['text_en'],
                isUser: isUser,
                time: message['time'],
                isArabic: isArabic,
              );
            },
          ),
        ),

        // ==============================================
        // SAMPLE QUESTIONS (if no messages)
        // ==============================================
        if (_messages.length == 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sampleQuestions.map((q) {
                return _SampleQuestionChip(
                  text: isArabic ? q['ar']! : q['en']!,
                  onTap: () {
                    _questionController.text = isArabic ? q['ar']! : q['en']!;
                    _sendMessage();
                  },
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 8),

        // ==============================================
        // INPUT
        // ==============================================
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
                  controller: _questionController,
                  decoration: InputDecoration(
                    hintText: isArabic
                        ? 'اسأل Zameel AI أي شيء...'
                        : 'Ask Zameel AI anything...',
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
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _isLoading ? Colors.grey : const Color(0xFF12AFA5),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : IconButton(
                        onPressed: _sendMessage,
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
    );
  }

  // ============================================================
  // SUMMARY TAB (التلخيص)
  // ============================================================

  Widget _buildSummaryTab(bool isArabic) {

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? '📝 أدخل النص للتلخيص' : '📝 Enter text to summarize',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: isArabic
                  ? 'الصق النص هنا للتلخيص...'
                  : 'Paste text here to summarize...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                if (_textController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArabic
                            ? '⚠️ يرجى إدخال النص للتلخيص'
                            : '⚠️ Please enter text to summarize',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                ZameelAIService.ask('Summarize the following text accurately and keep the key facts, dates, formulas, and conclusions: ${_textController.text}', mode: 'summary', language: isArabic ? 'ar' : 'en').then((answer) { if (mounted) setState(() { _summary = answer; }); }).catchError((_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArabic ? 'تعذر التلخيص الآن' : 'Summary unavailable'))); });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF12AFA5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isArabic ? '📄 تلخيص النص' : '📄 Summarize',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (_summary != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Text(
                _summary!,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // EXPLAIN TAB (الشرح)
  // ============================================================

  Widget _buildExplainTab(bool isArabic) {

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? '📖 أدخل المفهوم للشرح' : '📖 Enter concept to explain',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: isArabic
                  ? 'اكتب المفهوم أو الفكرة التي تريد شرحها...'
                  : 'Write the concept or idea you want explained...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                if (_textController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArabic
                            ? '⚠️ يرجى إدخال المفهوم للشرح'
                            : '⚠️ Please enter concept to explain',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                ZameelAIService.ask('Explain this university concept clearly, step by step, with a simple example and common mistakes: ${_textController.text}', mode: 'explain', language: isArabic ? 'ar' : 'en').then((answer) { if (mounted) setState(() { _explanation = answer; }); }).catchError((_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArabic ? 'تعذر الشرح الآن' : 'Explanation unavailable'))); });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF12AFA5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isArabic ? '📖 شرح المفهوم' : '📖 Explain',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (_explanation != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Text(
                _explanation!,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// AI TAB BUTTON
// ============================================================

class _AITabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _AITabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFF12AFA5)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF12AFA5)
                  : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MESSAGE BUBBLE
// ============================================================

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final String time;
  final bool isArabic;

  const _MessageBubble({
    required this.message,
    required this.isUser,
    required this.time,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF12AFA5) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: isUser ? Colors.white : Colors.black,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: isUser ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 10,
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

// ============================================================
// SAMPLE QUESTION CHIP
// ============================================================

class _SampleQuestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SampleQuestionChip({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: onTap,
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
    );
  }
}