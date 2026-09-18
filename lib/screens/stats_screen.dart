import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/remaining_services.dart';
import 'package:zameel/theme/app_theme.dart';

class StatsScreen extends StatefulWidget {
  final int postsCount;
  final int likesCount;
  final int commentsCount;
  final int friendsCount;
  final int savedBooksCount;
  final int activeDays;

  const StatsScreen({
    super.key,
    required this.postsCount,
    required this.likesCount,
    required this.commentsCount,
    required this.friendsCount,
    required this.savedBooksCount,
    required this.activeDays,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _weekly = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        RemainingServices.activityStats(),
        RemainingServices.weeklyActivity(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = values[0] as Map<String, dynamic>;
        _weekly = values[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _value(String key, int fallback) {
    final value = _stats[key];
    return value is num ? value.toInt() : fallback;
  }

  String _weekday(DateTime date, bool ar) {
    const arDays = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];
    const enDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (ar ? arDays : enDays)[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    final postsCount = _value('posts', widget.postsCount);
    final likesCount = _value('likes', widget.likesCount);
    final commentsCount = _value('comments', widget.commentsCount);
    final friendsCount = _value('friends', widget.friendsCount);
    final savedBooksCount = _value('saved_books', widget.savedBooksCount);
    final activeDays = _value('active_days', widget.activeDays);

    final stats = <Map<String, dynamic>>[
      {'icon': Icons.article_rounded, 'label_ar': 'المنشورات', 'label_en': 'Posts', 'value': postsCount},
      {'icon': Icons.favorite_rounded, 'label_ar': 'الإعجابات', 'label_en': 'Likes', 'value': likesCount},
      {'icon': Icons.comment_rounded, 'label_ar': 'التعليقات', 'label_en': 'Comments', 'value': commentsCount},
      {'icon': Icons.people_rounded, 'label_ar': 'الزملاء', 'label_en': 'Colleagues', 'value': friendsCount},
      {'icon': Icons.menu_book_rounded, 'label_ar': 'الكتب', 'label_en': 'Books', 'value': savedBooksCount},
      {'icon': Icons.calendar_today_rounded, 'label_ar': 'أيام النشاط', 'label_en': 'Active Days', 'value': activeDays},
    ];

    final weeklyActivity = _weekly.isEmpty
        ? List.generate(7, (index) {
            final date = DateTime.now().subtract(Duration(days: 6 - index));
            return {'day': _weekday(date, isArabic), 'value': 0};
          })
        : _weekly.map((row) {
            final date = DateTime.tryParse(row['day_date']?.toString() ?? '') ?? DateTime.now();
            return {
              'day': _weekday(date, isArabic),
              'value': (row['activity_count'] as num?)?.toInt() ?? 0,
            };
          }).toList();

    final maxValue = weeklyActivity.fold<int>(1, (current, item) {
      final value = item['value'] as int;
      return value > current ? value : current;
    });

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '📊 الإحصاءات الشخصية' : '📊 Activity Stats',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            isArabic ? '📈 إحصائياتك الحقيقية' : '📈 Your Live Stats',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isArabic ? 'محسوبة من نشاط حسابك في Zameel' : 'Calculated from your Zameel account activity',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.1,
                            ),
                            itemCount: stats.length,
                            itemBuilder: (context, index) {
                              final stat = stats[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(25),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(stat['icon'] as IconData, color: Colors.white, size: 28),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${stat['value']}',
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      isArabic ? stat['label_ar'].toString() : stat['label_en'].toString(),
                                      style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 11),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isArabic ? '📅 النشاط الأسبوعي' : '📅 Weekly Activity',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppTheme.muted.withAlpha(25), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: SizedBox(
                        height: 135,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: weeklyActivity.map((day) {
                            final value = day['value'] as int;
                            final height = value == 0 ? 4.0 : 100.0 * value / maxValue;
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('$value', style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                                const SizedBox(height: 4),
                                Container(
                                  width: 28,
                                  height: height,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(day['day'].toString(), style: TextStyle(fontSize: 11, color: AppTheme.muted.shade600)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isArabic ? '🏆 الإنجازات' : '🏆 Achievements',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _AchievementChip(icon: Icons.emoji_events_rounded, label: isArabic ? 'أول منشور' : 'First Post', color: AppTheme.tertiary, unlocked: postsCount >= 1),
                        _AchievementChip(icon: Icons.favorite_rounded, label: isArabic ? '100 إعجاب' : '100 Likes', color: Colors.redAccent, unlocked: likesCount >= 100),
                        _AchievementChip(icon: Icons.people_rounded, label: isArabic ? '10 زملاء' : '10 Colleagues', color: AppTheme.primary, unlocked: friendsCount >= 10),
                        _AchievementChip(icon: Icons.menu_book_rounded, label: isArabic ? '5 كتب' : '5 Books', color: AppTheme.primaryDark, unlocked: savedBooksCount >= 5),
                        _AchievementChip(icon: Icons.calendar_month_rounded, label: isArabic ? '30 يوم نشاط' : '30 Active Days', color: AppTheme.primary, unlocked: activeDays >= 30),
                        _AchievementChip(icon: Icons.comment_rounded, label: isArabic ? '50 تعليق' : '50 Comments', color: AppTheme.primary, unlocked: commentsCount >= 50),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool unlocked;

  const _AchievementChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: unlocked ? color.withAlpha(25) : AppTheme.muted.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: unlocked ? color : AppTheme.muted.shade300, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: unlocked ? color : AppTheme.muted.shade400, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: unlocked ? color : AppTheme.muted.shade500,
              fontWeight: unlocked ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          if (unlocked) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
          ],
        ],
      ),
    );
  }
}
