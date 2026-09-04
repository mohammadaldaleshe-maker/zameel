import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

// ============================================================
// POLLS SCREEN - استطلاعات الرأي (معدل)
// ============================================================

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  // ✅ استطلاعات الرأي مع حالة التصويت
  List<Map<String, dynamic>> polls = [
    {
      'id': 1,
      'question_ar': 'ما هي أفضل لغة برمجة للبدء بها؟',
      'question_en': 'What is the best programming language to start with?',
      'options': ['Python', 'Java', 'C++', 'JavaScript'],
      'votes': [45, 20, 15, 30],
      'totalVotes': 110,
      'isClosed': false,
      'userVoted': false,
      'userChoice': -1,
      'createdBy_ar': 'محمد أحمد',
      'createdBy_en': 'Mohammed Ahmed',
      'time_ar': 'منذ 3 ساعات',
      'time_en': '3 hours ago',
    },
    {
      'id': 2,
      'question_ar': 'ما هو أفضل وقت للمذاكرة؟',
      'question_en': 'What is the best time to study?',
      'options': ['الصباح الباكر', 'الظهر', 'المساء', 'الليل'],
      'votes': [30, 15, 25, 40],
      'totalVotes': 110,
      'isClosed': true,
      'userVoted': false,
      'userChoice': -1,
      'createdBy_ar': 'سارة علي',
      'createdBy_en': 'Sara Ali',
      'time_ar': 'منذ يومين',
      'time_en': '2 days ago',
    },
    {
      'id': 3,
      'question_ar': 'ما هي أفضل جامعة في الأردن؟',
      'question_en': 'What is the best university in Jordan?',
      'options': ['الجامعة الأردنية', 'جامعة العلوم والتكنولوجيا', 'جامعة اليرموك', 'الجامعة الهاشمية'],
      'votes': [50, 35, 20, 15],
      'totalVotes': 120,
      'isClosed': false,
      'userVoted': false,
      'userChoice': -1,
      'createdBy_ar': 'أحمد خالد',
      'createdBy_en': 'Ahmed Khaled',
      'time_ar': 'منذ 5 ساعات',
      'time_en': '5 hours ago',
    },
  ];

  void _vote(int pollIndex, int optionIndex) {
    setState(() {
      if (polls[pollIndex]['userVoted']) {
        // ✅ إذا كان المستخدم قد صوت، لا يمكنه التصويت مرة أخرى
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? '❌ لقد قمت بالتصويت مسبقاً' : '❌ You already voted'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ✅ تسجيل التصويت
      polls[pollIndex]['votes'][optionIndex]++;
      polls[pollIndex]['totalVotes']++;
      polls[pollIndex]['userVoted'] = true;
      polls[pollIndex]['userChoice'] = optionIndex;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? '✅ تم التصويت بنجاح!' : '✅ Voted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    });
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
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: polls.length,
          itemBuilder: (context, index) {
            final poll = polls[index];
            return _PollCard(
              poll: poll,
              pollIndex: index,
              isArabic: isArabic,
              onVote: _vote,
            );
          },
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

  const _PollCard({
    required this.poll,
    required this.pollIndex,
    required this.isArabic,
    required this.onVote,
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
            color: Colors.grey.withAlpha(25),
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
                backgroundColor: Color(0xFFDDF6F3),
                child: Icon(
                  Icons.person_rounded,
                  color: Color(0xFF087F78),
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
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isArabic ? '🔒 مغلق' : '🔒 Closed',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
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
                onTap: isClosed || userVoted
                    ? null
                    : () {
                        onVote(pollIndex, optionIndex);
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUserChoice
                        ? const Color(0xFF12AFA5).withAlpha(25)
                        : (isClosed || userVoted
                            ? Colors.grey.shade100
                            : const Color(0xFFF5FAF9)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isUserChoice
                          ? const Color(0xFF12AFA5)
                          : (isClosed || userVoted
                              ? Colors.grey.shade300
                              : const Color(0xFF12AFA5).withAlpha(51)),
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
                                color: isClosed ? Colors.grey.shade600 : Colors.black,
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
                                    ? const Color(0xFF12AFA5)
                                    : Colors.grey.shade600,
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
                            backgroundColor: Colors.grey.shade200,
                            color: isUserChoice
                                ? const Color(0xFF12AFA5)
                                : const Color(0xFF12AFA5).withAlpha(179),
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
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                isArabic
                    ? '${poll['totalVotes']} صوت'
                    : '${poll['totalVotes']} votes',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const Spacer(),
              if (!isClosed && !userVoted)
                Text(
                  isArabic ? 'اضغط للتصويت 👆' : 'Tap to vote 👆',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF12AFA5),
                  ),
                ),
              if (!isClosed && userVoted)
                Text(
                  isArabic ? '✅ تم التصويت' : '✅ Voted',
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