import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zameel/theme/app_theme.dart';

class ZameelDailyHub extends StatefulWidget {
  final bool isArabic;
  final VoidCallback onStories;
  final VoidCallback onChat;
  final VoidCallback onCalendar;
  final VoidCallback onGroups;
  final VoidCallback onBooks;
  final VoidCallback onCreatePost;
  final VoidCallback onSocial;
  final String? profileImageUrl;

  const ZameelDailyHub({
    super.key,
    required this.isArabic,
    required this.onStories,
    required this.onChat,
    required this.onCalendar,
    required this.onGroups,
    required this.onBooks,
    required this.onCreatePost,
    required this.onSocial,
    this.profileImageUrl,
  });

  @override
  State<ZameelDailyHub> createState() => _ZameelDailyHubState();
}

class _ZameelDailyHubState extends State<ZameelDailyHub> {
  int _streak = 1;
  bool _checkedIn = false;
  final List<bool> _tasks = [false, false, false];

  static const _streakKey = 'zameel_daily_streak';
  static const _checkInKey = 'zameel_daily_checkin';
  static const _taskPrefix = 'zameel_daily_task_';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final lastCheckIn = prefs.getString(_checkInKey);
    final storedStreak = prefs.getInt(_streakKey) ?? 0;

    if (!mounted) return;
    setState(() {
      _streak = storedStreak == 0 ? 1 : storedStreak;
      _checkedIn = lastCheckIn == today;
      for (var i = 0; i < _tasks.length; i++) {
        _tasks[i] = prefs.getBool('$_taskPrefix$i-$today') ?? false;
      }
    });
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _checkIn() async {
    if (_checkedIn) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    await prefs.setString(_checkInKey, today);
    await prefs.setInt(_streakKey, _streak + 1);
    if (!mounted) return;
    setState(() {
      _checkedIn = true;
      _streak += 1;
    });
  }

  Future<void> _toggleTask(int index) async {
    final today = _dateKey(DateTime.now());
    final next = !_tasks[index];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_taskPrefix$index-$today', next);
    if (!mounted) return;
    setState(() => _tasks[index] = next);
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.isArabic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppTheme.primary,
        ),
        child: Row(
          children: [
            Expanded(child: _quickAction(Icons.chat_bubble_rounded, ar ? 'دردشة' : 'Chat', widget.onChat)),
            Expanded(child: _quickAction(Icons.calendar_month_rounded, ar ? 'جدولي' : 'Schedule', widget.onCalendar)),
            Expanded(child: _quickAction(Icons.groups_rounded, ar ? 'مجموعاتي' : 'Groups', widget.onGroups)),
            Expanded(child: _quickAction(Icons.menu_book_rounded, ar ? 'كتب' : 'Books', widget.onBooks)),
            Expanded(child: _quickAction(Icons.movie_creation_rounded, ar ? 'فيديو' : 'Videos', widget.onSocial)),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: Colors.white.withAlpha(35), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _task(int index, String title) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: _tasks[index],
      onChanged: (_) => _toggleTask(index),
      title: Text(title, style: TextStyle(fontSize: 13, decoration: _tasks[index] ? TextDecoration.lineThrough : null)),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
