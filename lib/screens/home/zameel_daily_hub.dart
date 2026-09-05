import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final completed = _tasks.where((v) => v).length;
    final progress = completed / _tasks.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF18D3C3), Color(0xFF18D3C3)],
              ),
              boxShadow: const [
                BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x226C63FF)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.auto_awesome_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ar ? 'يومك في زميل' : 'Your day on Zameel',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              ar ? 'أهم ما تحتاجه في مكان واحد' : 'Everything important in one place',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: _checkIn,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(_checkedIn ? 35 : 255),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(_checkedIn ? Icons.check_rounded : Icons.local_fire_department_rounded,
                                  color: _checkedIn ? Colors.white : const Color(0xFFFF8A65), size: 20),
                              Text(
                                '$_streak',
                                style: TextStyle(
                                  color: _checkedIn ? Colors.white : const Color(0xFF0B9F95),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _quickAction(Icons.camera_alt_rounded, ar ? 'حالات' : 'Stories', widget.onStories)),
                      Expanded(child: _quickAction(Icons.chat_bubble_rounded, ar ? 'دردشة' : 'Chat', widget.onChat)),
                      Expanded(child: _quickAction(Icons.calendar_month_rounded, ar ? 'جدولي' : 'Schedule', widget.onCalendar)),
                      Expanded(child: _quickAction(Icons.groups_rounded, ar ? 'مجموعاتي' : 'Groups', widget.onGroups)),
                      Expanded(child: _quickAction(Icons.menu_book_rounded, ar ? 'كتب' : 'Books', widget.onBooks)),
                      Expanded(child: _quickAction(Icons.groups_rounded, ar ? 'مجتمع الزملاء' : 'Zameel Community', widget.onSocial)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withAlpha(235),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor.withAlpha(70)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.today_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(ar ? 'خطتك السريعة لليوم' : 'Your quick plan for today',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Text('$completed/3', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(value: progress, minHeight: 6),
                ),
                const SizedBox(height: 6),
                _task(0, ar ? 'راجع مادة اليوم' : 'Review today’s course'),
                _task(1, ar ? 'تفاعل مع مجموعتك' : 'Check your groups'),
                _task(2, ar ? 'أنجز شيئًا مفيدًا' : 'Complete one useful thing'),
                Align(
                  alignment: ar ? Alignment.centerRight : Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onCreatePost,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(ar ? 'شارك إنجازك اليوم' : 'Share today’s win'),
                  ),
                ),
              ],
            ),
          ),
        ],
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
