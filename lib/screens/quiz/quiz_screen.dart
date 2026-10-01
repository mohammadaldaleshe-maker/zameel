import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/quiz_progress.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.isArabic});
  final bool isArabic;
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _db = Supabase.instance.client;
  Map<String, dynamic>? _question;
  Map<String, dynamic>? _answer;
  bool _busy = false;
  String? _error;
  int? _rank;
  Timer? _nextTimer;
  String _t(String ar, String en) => widget.isArabic ? ar : en;
  @override
  void initState() {
    super.initState();
    _next();
  }
  @override
  void dispose() {
    _nextTimer?.cancel();
    super.dispose();
  }
  Future<void> _next() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final data = Map<String, dynamic>.from(await _db.rpc('zameel_quiz_next') as Map);
      if (!mounted) return;
      setState(() { _question = data; _answer = null; });
      unawaited(_loadRank());
    } catch (_) {
      if (mounted) setState(() => _error = _t('تعذر جلب السؤال. حاول مجددًا.', 'Could not load the question. Please retry.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _loadRank() async {
    try {
      final result = await _db.rpc('zameel_quiz_leaderboard');
      if (mounted && result is Map) setState(() => _rank = (result['own_rank'] as num?)?.toInt());
    } catch (_) { /* Ranking must not block a question. */ }
  }
  Future<void> _choose(int selected) async {
    if (_busy || _answer != null || _question?['available'] != true) return;
    final attempt = _question!['attempt_id'];
    setState(() { _busy = true; _error = null; });
    try {
      final data = Map<String, dynamic>.from(await _db.rpc('zameel_quiz_answer', params: {'p_attempt_id': attempt, 'p_selected': selected}) as Map);
      if (!mounted) return;
      setState(() { _answer = data; _question!['score'] = data['score']; });
      _nextTimer = Timer(const Duration(seconds: 2), _next);
    } catch (_) {
      if (mounted) setState(() => _error = _t('تعذر تأكيد الإجابة. أعد المحاولة؛ لن تُحتسب مرتين.', 'Could not confirm your answer. Retry safely; points are awarded once.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _leaderboard() async {
    try {
      final data = Map<String, dynamic>.from(await _db.rpc('zameel_quiz_leaderboard') as Map);
      if (!mounted) return;
      final rows = (data['rows'] as List? ?? []).whereType<Map>().toList();
      await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (context) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(20), child: Text(_t('أفضل عشرة لاعبين', 'Top ten players'), style: Theme.of(context).textTheme.titleLarge)),
          Expanded(child: ListView(children: rows.map((row) {
            final rank = (row['rank'] as num).toInt();
            final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank';
            return ListTile(leading: SizedBox(width: 90, child: Row(mainAxisSize: MainAxisSize.min, children: [Text(medal, style: const TextStyle(fontSize: 24)), const SizedBox(width: 6), CircleAvatar(radius: 19, backgroundImage: (row['profile_image']?.toString() ?? '').isEmpty ? null : NetworkImage(row['profile_image'].toString()), child: (row['profile_image']?.toString() ?? '').isEmpty ? const Icon(Icons.person) : null)])), title: Text('${row['name'] ?? ''}'),
              subtitle: Text(QuizProgress((row['score'] as num).toInt()).label(widget.isArabic)),
              trailing: Text('${row['score']}'));
          }).toList())),
          Padding(padding: const EdgeInsets.all(16), child: Text(_t('ترتيبك: ${data['own_rank'] ?? '—'}', 'Your rank: ${data['own_rank'] ?? '—'}'))),
        ]),
      )));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('تعذر تحميل الترتيب', 'Could not load rankings'))));
    }
  }
  Future<void> _report() async {
    final questionId = _question?['question_id'];
    if (questionId == null) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: Text(_t('الإبلاغ عن خطأ في السؤال', 'Report a question error')),
      content: TextField(controller: controller, maxLength: 1000, maxLines: 3),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('إلغاء', 'Cancel'))),
        TextButton(onPressed: () { if (controller.text.trim().length >= 5) Navigator.pop(context, controller.text.trim()); }, child: Text(_t('إرسال', 'Send')))],
    ));
    controller.dispose();
    if (reason == null || !mounted) return;
    try {
      await _db.rpc('zameel_quiz_report', params: {'p_question_id': questionId, 'p_reason': reason});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('تم إرسال البلاغ للمراجعة', 'Report submitted for review'))));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('تعذر إرسال البلاغ', 'Could not send report'))));
    }
  }
  @override
  Widget build(BuildContext context) {
    final progress = QuizProgress((_question?['score'] as num?)?.toInt() ?? 0);
    final options = (_question?[widget.isArabic ? 'options_ar' : 'options_en'] as List?) ?? [];
    return Directionality(textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(
      appBar: AppBar(title: Text(_t('كويز', 'Quiz')), actions: [IconButton(onPressed: _leaderboard, icon: const Icon(Icons.emoji_events_outlined), tooltip: _t('الترتيب', 'Rankings'))]),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: Image.asset('assets/branding/zameel_mark.png', height: 64)),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.center, spacing: 12, children: [Chip(label: Text(progress.label(widget.isArabic))),
          Chip(label: Text(_t('${progress.correct} نقطة', '${progress.correct} points'))),
          Chip(label: Text(_t('ترتيبك: ${_rank ?? '—'}', 'Rank: ${_rank ?? '—'}')))]),
        if (progress.requiredInLevel != null) ...[
          const SizedBox(height: 12), LinearProgressIndicator(value: progress.earnedInLevel / progress.requiredInLevel!),
          Text('${progress.earnedInLevel}/${progress.requiredInLevel}', textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        if (_question?['available'] == true) ...[
          Text(_t('السؤال ${_question!['ordinal']}', 'Question ${_question!['ordinal']}'), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('${_question![widget.isArabic ? 'question_ar' : 'question_en']}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          for (var i = 0; i < options.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: OutlinedButton(
            onPressed: _busy || _answer != null ? null : () => _choose(i),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(18), backgroundColor: _answer == null ? null :
              _answer!['correct_index'] == i ? Colors.green.shade100 : _answer!['selected_index'] == i ? Colors.red.shade100 : null,
              disabledForegroundColor: Colors.black87),
            child: Row(children: [Expanded(child: Text('${options[i]}')),
              if (_answer?['correct_index'] == i) const Icon(Icons.check, color: Colors.green)
              else if (_answer?['selected_index'] == i) const Icon(Icons.close, color: Colors.red)]),
          )),
          TextButton(onPressed: _busy ? null : _report, child: Text(_t('الإبلاغ عن السؤال', 'Report question'))),
        ] else if (!_busy && _error == null) Text(_t('لا توجد أسئلة مراجعة متاحة لهذا المستوى حاليًا. تقدّمك محفوظ.', 'No reviewed questions are available at this level yet. Your progress is saved.'), textAlign: TextAlign.center),
        if (_busy) const Center(child: CircularProgressIndicator()),
        if (_error != null) ...[Text(_error!, textAlign: TextAlign.center), TextButton(onPressed: _next, child: Text(_t('إعادة المحاولة', 'Retry')))],
      ])),
    ));
  }
}
