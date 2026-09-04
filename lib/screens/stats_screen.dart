import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/translations.dart';

// ============================================================
// STATS SCREEN - الإحصاءات الشخصية (معدل)
// ============================================================

class StatsScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    final List<Map<String, dynamic>> stats = [
      {
        'icon': Icons.post_add_rounded,
        'label_ar': 'المنشورات',
        'label_en': 'Posts',
        'value': postsCount,
        'color': const Color(0xFF12AFA5),
      },
      {
        'icon': Icons.favorite_rounded,
        'label_ar': 'الإعجابات',
        'label_en': 'Likes',
        'value': likesCount,
        'color': Colors.redAccent,
      },
      {
        'icon': Icons.comment_rounded,
        'label_ar': 'التعليقات',
        'label_en': 'Comments',
        'value': commentsCount,
        'color': const Color(0xFFFF9800),
      },
      {
        'icon': Icons.people_rounded,
        'label_ar': 'الأصدقاء',
        'label_en': 'Friends',
        'value': friendsCount,
        'color': const Color(0xFF2196F3),
      },
      {
        'icon': Icons.menu_book_rounded,
        'label_ar': 'الكتب المحفوظة',
        'label_en': 'Saved Books',
        'value': savedBooksCount,
        'color': const Color(0xFF9C27B0),
      },
      {
        'icon': Icons.calendar_today_rounded,
        'label_ar': 'أيام النشاط',
        'label_en': 'Active Days',
        'value': activeDays,
        'color': const Color(0xFFE91E63),
      },
    ];

    final List<Map<String, dynamic>> weeklyActivity = [
      {'day_ar': 'أحد', 'day_en': 'Sun', 'value': 4},
      {'day_ar': 'إثنين', 'day_en': 'Mon', 'value': 7},
      {'day_ar': 'ثلاثاء', 'day_en': 'Tue', 'value': 5},
      {'day_ar': 'أربعاء', 'day_en': 'Wed', 'value': 9},
      {'day_ar': 'خميس', 'day_en': 'Thu', 'value': 6},
      {'day_ar': 'جمعة', 'day_en': 'Fri', 'value': 3},
      {'day_ar': 'سبت', 'day_en': 'Sat', 'value': 2},
    ];

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '📊 الإحصاءات الشخصية' : '📊 Activity Stats',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF12AFA5), Color(0xFF087F78)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      isArabic ? '📈 إحصائياتك' : '📈 Your Stats',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isArabic
                          ? 'نشاطك في التطبيق حتى الآن'
                          : 'Your activity so far',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
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
                              Icon(
                                stat['icon'],
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${stat['value']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isArabic ? stat['label_ar'] : stat['label_en'],
                                style: TextStyle(
                                  color: Colors.white.withAlpha(179),
                                  fontSize: 11,
                                ),
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Container(
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: weeklyActivity.map((day) {
                    final maxValue = 10;
                    final height = (day['value'] / maxValue) * 100;
                    return Column(
                      children: [
                        Container(
                          width: 28,
                          height: height,
                          decoration: BoxDecoration(
                            color: const Color(0xFF12AFA5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isArabic ? day['day_ar'] : day['day_en'],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                isArabic ? '🏆 الإنجازات' : '🏆 Achievements',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AchievementChip(
                    icon: Icons.emoji_events_rounded,
                    label: isArabic ? 'أول منشور' : 'First Post',
                    color: const Color(0xFFFFD700),
                    unlocked: postsCount >= 1,
                  ),
                  _AchievementChip(
                    icon: Icons.favorite_rounded,
                    label: isArabic ? '100 إعجاب' : '100 Likes',
                    color: Colors.redAccent,
                    unlocked: likesCount >= 100,
                  ),
                  _AchievementChip(
                    icon: Icons.people_rounded,
                    label: isArabic ? '10 أصدقاء' : '10 Friends',
                    color: const Color(0xFF2196F3),
                    unlocked: friendsCount >= 10,
                  ),
                  _AchievementChip(
                    icon: Icons.menu_book_rounded,
                    label: isArabic ? '5 كتب' : '5 Books',
                    color: const Color(0xFF9C27B0),
                    unlocked: savedBooksCount >= 5,
                  ),
                  _AchievementChip(
                    icon: Icons.calendar_month_rounded,
                    label: isArabic ? '30 يوم نشاط' : '30 Active Days',
                    color: const Color(0xFFE91E63),
                    unlocked: activeDays >= 30,
                  ),
                  _AchievementChip(
                    icon: Icons.comment_rounded,
                    label: isArabic ? '50 تعليق' : '50 Comments',
                    color: const Color(0xFFFF9800),
                    unlocked: commentsCount >= 50,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ACHIEVEMENT CHIP
// ============================================================
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
        color: unlocked ? color.withAlpha(25) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked ? color : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: unlocked ? color : Colors.grey.shade400,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: unlocked ? color : Colors.grey.shade500,
              fontWeight: unlocked ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          if (unlocked) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }
}