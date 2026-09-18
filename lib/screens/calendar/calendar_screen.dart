import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'package:intl/intl.dart';
import 'package:zameel/theme/app_theme.dart';
import '../../services/remaining_services.dart';

// ============================================================
// ZAMEEL CALENDAR SCREEN
// ============================================================

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  final List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final rows = await RemainingServices.calendarEvents();
      if (!mounted) return;
      setState(() {
        _events
          ..clear()
          ..addAll(rows.map(_eventFromRow));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _eventFromRow(Map<String, dynamic> row) {
    final type = row['event_type']?.toString() ?? 'event';
    final rawTime = row['event_time']?.toString() ?? '';
    return {
      'id': row['id']?.toString() ?? '',
      'title_ar': row['title']?.toString() ?? '',
      'title_en': row['title']?.toString() ?? '',
      'date': DateTime.tryParse(row['event_date']?.toString() ?? '') ?? DateTime.now(),
      'time': rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime,
      'type_ar': _typeLabel(type, true),
      'type_en': _typeLabel(type, false),
      'event_type': type,
      'color': AppTheme.primary,
      'icon': _typeIcon(type),
    };
  }

  String _typeLabel(String type, bool ar) {
    switch (type) {
      case 'lecture':
        return ar ? 'محاضرة' : 'Lecture';
      case 'exam':
        return ar ? 'امتحان' : 'Exam';
      case 'assignment':
        return ar ? 'واجب' : 'Assignment';
      case 'event':
        return ar ? 'فعالية' : 'Event';
      default:
        return ar ? 'أخرى' : 'Other';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'lecture':
        return Icons.school_rounded;
      case 'exam':
        return Icons.edit_rounded;
      case 'assignment':
        return Icons.assignment_rounded;
      case 'event':
        return Icons.event_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }

  String _typeCode(String value) {
    if (value == 'محاضرة' || value == 'Lecture') return 'lecture';
    if (value == 'امتحان' || value == 'Exam') return 'exam';
    if (value == 'واجب' || value == 'Assignment') return 'assignment';
    if (value == 'فعالية' || value == 'Event') return 'event';
    return 'other';
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday;

    final List<DateTime> days = [];
    // أيام الشهر السابق
    for (int i = startWeekday - 1; i > 0; i--) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, 1 - i));
    }
    // أيام الشهر الحالي
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }
    // أيام الشهر التالي
    final remaining = 42 - days.length;
    for (int i = 1; i <= remaining; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month + 1, i));
    }
    return days;
  }

  List<Map<String, dynamic>> _getEventsForDate(DateTime date) {
    return _events.where((event) {
      final eventDate = event['date'] as DateTime;
      return eventDate.year == date.year &&
          eventDate.month == date.month &&
          eventDate.day == date.day;
    }).toList();
  }

  bool _hasEvents(DateTime date) {
    return _getEventsForDate(date).isNotEmpty;
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
            isArabic ? '📅 التقويم الجامعي' : '📅 University Calendar',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () {
                _showAddEventDialog(context, isArabic);
              },
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // ====================================================
            // HEADER: الشهر والعام
            // ====================================================
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _previousMonth,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text(
                    isArabic
                        ? DateFormat('MMMM yyyy', 'ar').format(_currentMonth)
                        : DateFormat('MMMM yyyy', 'en').format(_currentMonth),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),

            // ====================================================
            // أيام الأسبوع
            // ====================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: isArabic
                    ? ['سبت', 'أحد', 'إثن', 'ثلاث', 'أربع', 'خميس', 'جمعة']
                        .map((day) => Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ),
                            ))
                        .toList()
                    : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        .map((day) => Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
              ),
            ),

            const Divider(height: 4),

            // ====================================================
            // أيام الشهر
            // ====================================================
            Expanded(
              flex: 2,
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.2,
                ),
                itemCount: _getDaysInMonth().length,
                itemBuilder: (context, index) {
                  final date = _getDaysInMonth()[index];
                  final isCurrentMonth =
                      date.month == _currentMonth.month;
                  final isToday = date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;
                  final isSelected = date.year == _selectedDate.year &&
                      date.month == _selectedDate.month &&
                      date.day == _selectedDate.day;
                  final hasEvents = _hasEvents(date);

                  return GestureDetector(
                    onTap: () {
                      _selectDate(date);
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : isToday
                                ? AppTheme.muted.shade200
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isToday && !isSelected
                            ? Border.all(
                                color: AppTheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            date.day.toString(),
                            style: TextStyle(
                              color: isCurrentMonth
                                  ? (isSelected
                                      ? Colors.white
                                      : Colors.black)
                                  : AppTheme.muted.shade400,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                          if (hasEvents)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 4),

            // ====================================================
            // قائمة الأحداث لليوم المحدد
            // ====================================================
            Expanded(
              flex: 1,
              child: _buildEventsList(isArabic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList(bool isArabic) {
    final events = _getEventsForDate(_selectedDate);

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 48,
              color: AppTheme.muted.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? '📭 لا توجد أحداث في هذا اليوم'
                  : '📭 No events on this day',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.muted.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final rawColor = event['color'];
        final Color color = rawColor is Color
            ? rawColor
            : rawColor is int
                ? Color(rawColor)
                : AppTheme.primary;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                event['icon'],
                color: color,
                size: 22,
              ),
            ),
            title: Text(
              isArabic ? event['title_ar'] : event['title_en'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: AppTheme.muted.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  event['time'],
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.category_rounded,
                  size: 14,
                  color: AppTheme.muted.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  isArabic ? event['type_ar'] : event['type_en'],
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted.shade600,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              onPressed: () async {
                final id = event['id']?.toString() ?? '';
                try {
                  await RemainingServices.deleteCalendarEvent(id);
                  if (!mounted) return;
                  setState(() => _events.removeWhere((e) => e['id'] == event['id']));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isArabic ? '🗑️ تم حذف الحدث' : '🗑️ Event deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isArabic ? 'تعذر حذف الحدث' : 'Could not delete event')),
                  );
                }
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // إضافة حدث جديد
  // ============================================================

  void _showAddEventDialog(BuildContext context, bool isArabic) {
    final titleController = TextEditingController();
    final timeController = TextEditingController();
    DateTime selectedDate = _selectedDate;
    String selectedType = isArabic ? 'محاضرة' : 'Lecture';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              isArabic ? '➕ إضافة حدث جديد' : '➕ Add New Event',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ==============================================
                  // عنوان الحدث
                  // ==============================================
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'عنوان الحدث' : 'Event Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ==============================================
                  // التاريخ
                  // ==============================================
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded),
                    title: Text(
                      isArabic
                          ? '📅 التاريخ: ${DateFormat('yyyy-MM-dd', 'ar').format(selectedDate)}'
                          : '📅 Date: ${DateFormat('yyyy-MM-dd', 'en').format(selectedDate)}',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: isArabic
                            ? const Locale('ar')
                            : const Locale('en'),
                      );
                      if (date != null) {
                        selectedDate = date;
                        (dialogContext as Element).markNeedsBuild();
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // ==============================================
                  // الوقت
                  // ==============================================
                  TextField(
                    controller: timeController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'الوقت (مثال: 10:00)' : 'Time (e.g., 10:00)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.access_time_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ==============================================
                  // نوع الحدث
                  // ==============================================
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'نوع الحدث' : 'Event Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: isArabic
                        ? ['محاضرة', 'امتحان', 'واجب', 'فعالية']
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ))
                            .toList()
                        : ['Lecture', 'Exam', 'Assignment', 'Event']
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ))
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        selectedType = value;
                        // تحديث الأيقونة بناءً على النوع
                        if (value == 'محاضرة' || value == 'Lecture') {
                        } else if (value == 'امتحان' || value == 'Exam') {
                        } else if (value == 'واجب' || value == 'Assignment') {
                        } else if (value == 'فعالية' || value == 'Event') {
                        }
                        (dialogContext as Element).markNeedsBuild();
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic
                              ? '⚠️ يرجى إدخال عنوان الحدث'
                              : '⚠️ Please enter event title',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  if (timeController.text.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic
                              ? '⚠️ يرجى إدخال الوقت'
                              : '⚠️ Please enter time',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  try {
                    final row = await RemainingServices.addCalendarEvent(
                      title: titleController.text,
                      date: selectedDate,
                      time: timeController.text,
                      type: _typeCode(selectedType),
                    );
                    if (!mounted) return;
                    setState(() => _events.add(_eventFromRow(row)));
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic
                              ? '✅ تم إضافة الحدث بنجاح!'
                              : '✅ Event added successfully!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isArabic ? 'تعذر حفظ الحدث' : 'Could not save event')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(isArabic ? 'إضافة' : 'Add'),
              ),
            ],
          ),
        );
      },
    );
  }
}
