import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'package:zameel/theme/app_theme.dart';
import '../services/remaining_services.dart';

// ============================================================
// POLLS SCREEN - استطلاعات الرأي (معدل)
// ============================================================

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  List<Map<String, dynamic>> polls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls() async {
    try {
      final rows = await RemainingServices.polls();
      if (!mounted) return;
      setState(() {
        polls = rows.map(_pollFromRow).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _pollFromRow(Map<String, dynamic> row) {
    final rawOptions = row['options'];
    final options = rawOptions is List
        ? rawOptions.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    final choiceId = row['user_choice']?.toString();
    final choiceIndex = options.indexWhere((option) => option['id']?.toString() == choiceId);
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();
    final total = options.fold<int>(0, (sum, item) => sum + ((item['votes'] as num?)?.toInt() ?? 0));
    return {
      'id': row['id']?.toString() ?? '',
      'question_ar': row['question']?.toString() ?? '',
      'question_en': row['question']?.toString() ?? '',
      'options': options.map((item) => item['text']?.toString() ?? '').toList(),
      'optionIds': options.map((item) => item['id']?.toString() ?? '').toList(),
      'votes': options.map((item) => (item['votes'] as num?)?.toInt() ?? 0).toList(),
      'totalVotes': total,
      'isClosed': row['is_closed'] == true,
      'userVoted': choiceIndex >= 0,
      'userChoice': choiceIndex,
      'createdBy_ar': row['creator_name']?.toString() ?? 'زميل',
      'createdBy_en': row['creator_name']?.toString() ?? 'Zameel',
      'isOwner': row['is_owner'] == true,
      'time_ar': _relativeTime(created, true),
      'time_en': _relativeTime(created, false),
    };
  }

  String _relativeTime(DateTime? date, bool ar) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return ar ? 'الآن' : 'Now';
    if (diff.inHours < 1) return ar ? 'منذ ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return ar ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    return ar ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
  }

  Future<void> _vote(int pollIndex, int optionIndex) async {
    final poll = polls[pollIndex];
    if (poll['isClosed'] == true) return;
    if (poll['userChoice'] == optionIndex) return;
    try {
      final optionIds = poll['optionIds'] as List;
      await RemainingServices.votePoll(
        poll['id']?.toString() ?? '',
        optionIds[optionIndex]?.toString() ?? '',
      );
      await _loadPolls();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            poll['userVoted'] == true
                ? (isArabic ? '✅ تم تغيير اختيارك' : '✅ Vote changed')
                : (isArabic ? '✅ تم التصويت بنجاح!' : '✅ Voted successfully!'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تعذر تسجيل التصويت' : 'Could not record vote')),
      );
    }
  }

  Future<void> _deletePoll(Map<String, dynamic> poll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'حذف الاستطلاع' : 'Delete poll'),
        content: Text(
          isArabic
              ? 'سيتم حذف الاستطلاع وجميع الأصوات نهائيًا. هل تريد المتابعة؟'
              : 'The poll and all votes will be permanently deleted. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RemainingServices.deletePoll(poll['id']?.toString() ?? '');
      await _loadPolls();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? '🗑️ تم حذف الاستطلاع' : '🗑️ Poll deleted')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تعذر حذف الاستطلاع' : 'Could not delete poll')),
      );
    }
  }

  void _showCreatePoll() {
    final question = TextEditingController();
    final optionControllers = List.generate(4, (_) => TextEditingController());
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'إنشاء استطلاع' : 'Create poll'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: question,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isArabic ? 'السؤال' : 'Question',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(optionControllers.length, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: optionControllers[index],
                      decoration: InputDecoration(
                        labelText: isArabic ? 'الخيار ${index + 1}' : 'Option ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final options = optionControllers
                  .map((controller) => controller.text.trim())
                  .where((value) => value.isNotEmpty)
                  .toList();
              if (question.text.trim().isEmpty || options.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isArabic ? 'أدخل سؤالاً وخيارين على الأقل' : 'Enter a question and at least two options')),
                );
                return;
              }
              try {
                await RemainingServices.createPoll(question.text, options);
                if (!mounted) return;
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _loadPolls();
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isArabic ? 'تعذر إنشاء الاستطلاع' : 'Could not create poll')),
                );
              }
            },
            child: Text(isArabic ? 'نشر' : 'Publish'),
          ),
        ],
      ),
    );
  }

  bool get isArabic => Provider.of<LanguageProvider>(context).isArabic;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '📊 استطلاعات الرأي' : '📊 Polls',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          actions: [
            IconButton(
              onPressed: _showCreatePoll,
              icon: const Icon(Icons.add_chart_rounded),
              tooltip: isArabic ? 'إنشاء استطلاع' : 'Create poll',
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadPolls,
                child: polls.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 180),
                          Center(child: Text(isArabic ? 'لا توجد استطلاعات بعد' : 'No polls yet')),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: polls.length,
                        itemBuilder: (context, index) {
                          final poll = polls[index];
                          return _PollCard(
                            poll: poll,
                            pollIndex: index,
                            isArabic: isArabic,
                            onVote: _vote,
                            onDelete: () => _deletePoll(poll),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}

// ============================================================
// POLL CARD
// ============================================================
class _PollCard extends StatelessWidget {
  final Map<String, dynamic> poll;
  final int pollIndex;
  final bool isArabic;
  final Function(int, int) onVote;
  final VoidCallback onDelete;

  const _PollCard({
    required this.poll,
    required this.pollIndex,
    required this.isArabic,
    required this.onVote,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final totalVotes = poll['totalVotes'] ?? 0;
    final isClosed = poll['isClosed'] ?? false;
    final userVoted = poll['userVoted'] ?? false;
    final userChoice = poll['userChoice'] ?? -1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.muted.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==============================================
          // HEADER
          // ==============================================
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryLight,
                child: Icon(
                  Icons.person_rounded,
                  color: AppTheme.primaryDark,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? poll['createdBy_ar'] : poll['createdBy_en'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      isArabic ? poll['time_ar'] : poll['time_en'],
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.muted.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.muted.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isArabic ? '🔒 مغلق' : '🔒 Closed',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.muted.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (userVoted && !isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isArabic ? '✅ تم التصويت' : '✅ Voted',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (poll['isOwner'] == true)
                IconButton(
                  tooltip: isArabic ? 'حذف الاستطلاع' : 'Delete poll',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ==============================================
          // QUESTION
          // ==============================================
          Text(
            isArabic ? poll['question_ar'] : poll['question_en'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // ==============================================
          // OPTIONS
          // ==============================================
          ...List.generate(poll['options'].length, (optionIndex) {
            final option = poll['options'][optionIndex];
            final votes = poll['votes'][optionIndex];
            final percentage = totalVotes > 0 ? (votes / totalVotes) * 100 : 0;
            final isUserChoice = userChoice == optionIndex;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: isClosed
                    ? null
                    : () {
                        onVote(pollIndex, optionIndex);
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUserChoice
                        ? AppTheme.primary.withAlpha(25)
                        : (isClosed
                            ? AppTheme.muted.shade100
                            : AppTheme.background),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isUserChoice
                          ? AppTheme.primary
                          : (isClosed
                              ? AppTheme.muted.shade300
                              : AppTheme.primary.withAlpha(51)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: isClosed ? AppTheme.muted.shade600 : Colors.black,
                                fontWeight: isUserChoice ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isClosed || userVoted) ...[
                            Text(
                              '${percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isUserChoice
                                    ? AppTheme.primary
                                    : AppTheme.muted.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isClosed || userVoted) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: AppTheme.muted.shade200,
                            color: isUserChoice
                                ? AppTheme.primary
                                : AppTheme.primary.withAlpha(179),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // ==============================================
          // FOOTER
          // ==============================================
          Row(
            children: [
              Icon(
                Icons.people_rounded,
                size: 14,
                color: AppTheme.muted.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                isArabic
                    ? '${poll['totalVotes']} صوت'
                    : '${poll['totalVotes']} votes',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.muted.shade500,
                ),
              ),
              const Spacer(),
              if (!isClosed && !userVoted)
                Text(
                  isArabic ? 'اضغط للتصويت 👆' : 'Tap to vote 👆',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                  ),
                ),
              if (!isClosed && userVoted)
                Text(
                  isArabic ? 'اضغط على خيار آخر لتغيير تصويتك' : 'Tap another option to change your vote',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
