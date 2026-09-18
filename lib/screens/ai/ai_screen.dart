import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../services/zameel_ai_service.dart';
import '../../theme/app_theme.dart';
import 'ai_faq_admin_screen.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final _service = ZameelAIService();
  final _question = TextEditingController();
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final List<_AIMessage> _messages = <_AIMessage>[];

  int _tab = 0;
  int _remaining = 50;
  bool _loading = false;
  bool _memory = true;
  bool _canManage = false;
  String? _conversationId;
  String? _result;
  bool _initializingChat = true;
  String _university = '';
  String _college = '';
  String _department = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final memory = await _service.memoryEnabled();
      final canManage = await _service.canManageKnowledge();
      final chatState = await _service.loadActiveChatState();
      if (!mounted) return;
      final isArabic = context.read<LanguageProvider>().isArabic;
      setState(() {
        _memory = memory;
        _canManage = canManage;
        _conversationId = chatState.conversationId;
        _university = chatState.university;
        _college = chatState.college;
        _department = chatState.department;
        _messages.clear();
        if (chatState.messages.isNotEmpty) {
          _messages.addAll(chatState.messages.map((row) => _AIMessage(
                text: row['content']?.toString() ?? '',
                isUser: row['role']?.toString() == 'user',
              )));
        } else {
          _messages.add(_AIMessage(
            text: _welcomeMessage(isArabic),
            isUser: false,
          ));
        }
        _initializingChat = false;
      });
      _scrollDown();
    } catch (_) {
      if (!mounted) return;
      final isArabic = context.read<LanguageProvider>().isArabic;
      setState(() {
        _messages
          ..clear()
          ..add(_AIMessage(text: _welcomeMessage(isArabic), isUser: false));
        _initializingChat = false;
      });
    }
  }

  String _welcomeMessage(bool ar) {
    if (ar) {
      final audience = _department.isNotEmpty
          ? 'طلبة تخصص $_department'
          : _college.isNotEmpty
              ? 'طلبة كلية $_college'
              : 'طلبة الجامعة';
      final location = [
        if (_college.isNotEmpty) 'كلية $_college',
        if (_university.isNotEmpty) _university,
      ].join(' في ');
      final where = location.isEmpty ? '' : ' في $location';
      return 'مرحباً! أنا زميل AI. أنا مخصص لمساعدة $audience$where. '
          'أقدم لك إرشادات عملية ودعماً أكاديمياً يناسب تخصصك وحياتك الجامعية. '
          'ملاحظة: إجاباتي إرشادية وغير رسمية، وعند وجود تعليمات جامعية رسمية يُرجع إلى جامعتك أو كليتك.';
    }
    final audience = _department.isNotEmpty
        ? 'students in $_department'
        : _college.isNotEmpty
            ? 'students in $_college'
            : 'university students';
    final place = [
      if (_college.isNotEmpty) _college,
      if (_university.isNotEmpty) _university,
    ].join(' at ');
    final where = place.isEmpty ? '' : ' at $place';
    return 'Hello! I am Zameel AI, tailored to help $audience$where. '
        'I provide practical academic guidance adapted to your field and university life. '
        'My guidance is informal; official university or faculty instructions remain the authoritative source.';
  }

  Future<void> _ask(String mode, [String? suppliedText]) async {
    final prompt = (suppliedText ?? _question.text).trim();
    if (prompt.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      if (mode == 'assistant') {
        _messages.add(_AIMessage(text: prompt, isUser: true));
        _question.clear();
      } else {
        _result = null;
      }
    });
    _scrollDown();

    try {
      final response = await _service.ask(
        prompt: prompt,
        mode: mode,
        conversationId: mode == 'assistant' ? _conversationId : null,
      );
      if (!mounted) return;
      setState(() {
        _remaining = response.remaining;
        _conversationId = response.conversationId ?? _conversationId;
        if (mode == 'assistant') {
          _messages.add(_AIMessage(
            text: response.answer,
            isUser: false,
            verified: response.verified,
            sources: response.sources,
          ));
        } else {
          _result = response.answer;
        }
      });
      _scrollDown();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        if (mode == 'assistant') {
          _messages
              .add(_AIMessage(text: message, isUser: false, isError: true));
        } else {
          _result = message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleMemory() async {
    final value = !_memory;
    try {
      await _service.setMemoryEnabled(value);
      if (mounted) setState(() => _memory = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديث إعداد الذاكرة')),
        );
      }
    }
  }

  Future<void> _clearHistory() async {
    await _service.clearHistory();
    if (!mounted) return;
    final ar = context.read<LanguageProvider>().isArabic;
    setState(() {
      _conversationId = null;
      _messages
        ..clear()
        ..add(_AIMessage(
          text: _welcomeMessage(ar),
          isUser: false,
        ));
    });
  }

  @override
  void dispose() {
    _question.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<LanguageProvider>().isArabic;
    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Zameel AI',
              style: TextStyle(fontWeight: FontWeight.w800)),
          centerTitle: true,
          actions: [
            if (_canManage)
              IconButton(
                tooltip: 'إدارة الإجابات المعتمدة',
                icon: const Icon(Icons.fact_check_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AIFaqAdminScreen()),
                ),
              ),
            PopupMenuButton<String>(
              onSelected: (value) =>
                  value == 'memory' ? _toggleMemory() : _clearHistory(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'memory',
                  child: Text(_memory
                      ? 'إيقاف استخدام السياق السابق'
                      : 'تفعيل استخدام السياق السابق'),
                ),
                const PopupMenuItem(
                    value: 'clear', child: Text('مسح محادثاتي')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            _QuotaBanner(remaining: _remaining),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.chat_bubble_outline),
                      label: Text('مساعد')),
                  ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.summarize_outlined),
                      label: Text('تلخيص')),
                  ButtonSegment(
                      value: 2,
                      icon: Icon(Icons.school_outlined),
                      label: Text('شرح')),
                ],
                selected: {_tab},
                onSelectionChanged: (value) => setState(() {
                  _tab = value.first;
                  _result = null;
                }),
              ),
            ),
            Expanded(child: _tab == 0 ? _assistant() : _textTool()),
          ],
        ),
      ),
    );
  }

  Widget _assistant() => Column(
        children: [
          Expanded(
            child: _initializingChat
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (_, index) => index == _messages.length
                        ? const _ThinkingBubble()
                        : _MessageBubble(message: _messages[index]),
                  ),
          ),
          const _PrivacyNote(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _question,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ask('assistant'),
                      decoration:
                          const InputDecoration(hintText: 'اكتب سؤالك هنا…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _loading ? null : () => _ask('assistant'),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _textTool() {
    final summary = _tab == 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          summary ? 'تلخيص ذكي' : 'شرح مبسّط',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(summary
            ? 'ألصق النص لتحصل على خلاصة مركّزة.'
            : 'اكتب الموضوع أو النص الذي تريد فهمه.'),
        const SizedBox(height: 14),
        TextField(
          controller: _text,
          minLines: 7,
          maxLines: 14,
          decoration: InputDecoration(
              hintText: summary ? 'ألصق النص هنا…' : 'ما الذي تريد شرحه؟'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading
              ? null
              : () => _ask(summary ? 'summary' : 'explain', _text.text),
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(summary
                  ? Icons.summarize_rounded
                  : Icons.auto_awesome_rounded),
          label: Text(summary ? 'لخّص النص' : 'اشرح لي'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  SelectableText(_result!, style: const TextStyle(height: 1.6)),
            ),
          ),
        ],
        const SizedBox(height: 10),
        const _PrivacyNote(),
      ],
    );
  }
}

class _AIMessage {
  const _AIMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.verified = false,
    this.sources = const [],
  });
  final String text;
  final bool isUser;
  final bool isError;
  final bool verified;
  final List<Map<String, dynamic>> sources;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _AIMessage message;

  @override
  Widget build(BuildContext context) => Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: message.isUser
                ? AppTheme.primary
                : message.isError
                    ? Colors.red.shade50
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.verified)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified_rounded, size: 17, color: Colors.teal),
                    SizedBox(width: 4),
                    Text('إجابة معتمدة من زميل',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              SelectableText(
                message.text,
                style: TextStyle(
                    color: message.isUser ? Colors.white : Colors.black87,
                    height: 1.5),
              ),
              if (message.sources.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'المصادر: ${message.sources.map((item) => item['title']?.toString() ?? 'مصدر معتمد').join('، ')}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      );
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();
  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      );
}

class _QuotaBanner extends StatelessWidget {
  const _QuotaBanner({required this.remaining});
  final int remaining;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppTheme.primary.withValues(alpha: .08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Text(
          'متبقي اليوم: $remaining من 50 سؤالاً ذكياً',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12),
        ),
      );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Text(
          'قد يخطئ زميل AI. لا تشارك كلمات المرور أو البيانات شديدة الحساسية.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      );
}
