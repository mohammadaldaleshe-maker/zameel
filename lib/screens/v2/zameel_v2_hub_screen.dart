import 'package:flutter/material.dart';

import '../ai/ai_screen.dart';
import '../books/books_screen.dart';
import '../calendar/calendar_screen.dart';
import '../campus/campus_screen.dart';
import '../chat/chat_screen.dart';
import '../friends/friends_screen.dart';
import '../groups/groups_screen.dart';
import '../jobs/jobs_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../home/zameel_daily_hub.dart';
import 'package:zameel/theme/app_theme.dart';

/// Zameel v2 product hub.
///
/// This screen intentionally composes the existing production modules instead
/// of replacing the stable v1.3.8 home feed in one risky migration. It is the
/// central launchpad for the complete v2 information architecture.
class ZameelV2HubScreen extends StatelessWidget {
  const ZameelV2HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = <_V2Module>[
      _V2Module('🏠', 'Zameel Daily', 'الرئيسية اليومية', ZameelDailyHub(isArabic: true, onStories: () {}, onChat: () {}, onCalendar: () {}, onGroups: () {}, onBooks: () {}, onCreatePost: () {}, onSocial: () {})),
      _V2Module('🌐', 'Community', 'المجتمع', const _InfoModuleScreen(title: 'المجتمع', subtitle: 'العامة • جامعتي • كليتي • تخصصي • مجموعاتي')),
      _V2Module('📚', 'Study', 'الدراسة', const BooksScreen()),
      _V2Module('🤖', 'AI Study', 'Zameel AI', const AIScreen()),
      _V2Module('👥', 'Classmates', 'زملائي', const FriendsScreen()),
      _V2Module('🎓', 'Study Groups', 'مجموعات الدراسة', const GroupsScreen()),
      _V2Module('💬', 'Messages', 'الرسائل', const ChatScreen()),
      _V2Module('🔔', 'Notifications', 'الإشعارات', const NotificationsScreen()),
      _V2Module('📅', 'Calendar', 'التقويم', CalendarScreen()),
      _V2Module('🏫', 'Campus', 'الحرم الجامعي', const CampusScreen()),
      _V2Module('💼', 'Jobs', 'الفرص والوظائف', const JobsScreen()),
      _V2Module('🔎', 'Search', 'البحث الشامل', const SearchScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zameel v2'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Zameel 2.0', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text('نظام حياة الطالب: مجتمع + دراسة + ذكاء اصطناعي + زملاء + حرم + مستقبل', style: TextStyle(color: Colors.white, fontSize: 15, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: modules.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (context, index) {
                final module = modules[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => module.page)),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(module.icon, style: const TextStyle(fontSize: 30)),
                          const SizedBox(height: 8),
                          Text(module.ar, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(module.en, style: TextStyle(fontSize: 11, color: AppTheme.muted.shade600)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            const _InfoModuleScreen(
              title: 'خريطة الإصدار',
              subtitle: 'V2.0 Foundation → V2.1 Daily → V2.2 Study → V2.3 People → V2.4 Campus → V2.5 Future',
            ),
          ],
        ),
      ),
    );
  }
}

class _V2Module {
  final String icon;
  final String en;
  final String ar;
  final Widget page;
  const _V2Module(this.icon, this.en, this.ar, this.page);
}

class _InfoModuleScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  const _InfoModuleScreen({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(color: AppTheme.muted.shade700, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
