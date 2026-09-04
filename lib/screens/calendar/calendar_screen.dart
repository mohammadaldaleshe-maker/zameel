import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/language_provider.dart';
import '../../services_calendar.dart';

class CalendarScreen extends StatefulWidget {
  final String universityKey;
  const CalendarScreen({super.key, this.universityKey = 'ju'});
  @override State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late String _universityKey;
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;
  String? _lastSync;

  final _universities = const {
    'ju': 'الجامعة الأردنية',
    'yu': 'جامعة اليرموك',
    'just': 'جامعة العلوم والتكنولوجيا الأردنية',
    'hu': 'الجامعة الهاشمية',
  };

  @override void initState() { super.initState(); _universityKey = widget.universityKey; _load(sync: true); }

  Future<void> _load({bool sync = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      List<Map<String, dynamic>> rows = [];
      if (sync) { rows = await ZameelCalendarService.loadFresh(_universityKey); }
      else { rows = await ZameelCalendarService.load(_universityKey); }
      if (!mounted) return;
      setState(() { _events = rows; _lastSync = rows.isNotEmpty ? rows.map((e) => e['fetched_at']).whereType<String>().fold<String?>(null, (a,b) => a == null || b.compareTo(a) > 0 ? b : a) : null; });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  List<DateTime> _days() {
    final first = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final days = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final list = <DateTime>[];
    for (int i = first.weekday - 1; i > 0; i--) list.add(DateTime(_currentMonth.year, _currentMonth.month, 1 - i));
    for (int i = 1; i <= days; i++) list.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    while (list.length < 42) list.add(DateTime(_currentMonth.year, _currentMonth.month + 1, list.length - days - first.weekday + 2));
    return list;
  }

  List<Map<String, dynamic>> _eventsFor(DateTime date) => _events.where((e) { final d = DateTime.tryParse(e['event_date']?.toString() ?? ''); return d != null && d.year == date.year && d.month == date.month && d.day == date.day; }).toList();

  Future<void> _openSource(String? url) async { if (url == null) return; final uri = Uri.tryParse(url); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }

  @override Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final days = _days();
    return Directionality(textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr, child: Scaffold(
      appBar: AppBar(
        title: Text(ar ? '📅 التقويم الجامعي' : '📅 University Calendar', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () => _load(sync: true), icon: const Icon(Icons.sync_rounded), tooltip: ar ? 'تحديث من الموقع الرسمي' : 'Sync official source')],
      ),
      body: _loading && _events.isEmpty ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: DropdownButtonFormField<String>(value: _universityKey, decoration: InputDecoration(labelText: ar ? 'الجامعة' : 'University', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: _universities.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) { if (v == null) return; setState(() { _universityKey = v; _events = []; }); _load(sync: true); })),
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Padding(padding: const EdgeInsets.all(10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)), icon: const Icon(Icons.chevron_left_rounded)), Text(ar ? DateFormat('MMMM yyyy', 'ar').format(_currentMonth) : DateFormat('MMMM yyyy', 'en').format(_currentMonth), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)), icon: const Icon(Icons.chevron_right_rounded))])),
        Row(children: (ar ? ['سبت','أحد','إثن','ثلاث','أربع','خميس','جمعة'] : ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']).map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))))).toList()),
        const Divider(),
        Expanded(flex: 2, child: GridView.builder(padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.15), itemCount: days.length, itemBuilder: (_, i) { final d = days[i]; final selected = d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day; final current = d.month == _currentMonth.month; final ev = _eventsFor(d); return InkWell(onTap: () => setState(() => _selectedDate = d), child: Container(margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: selected ? Theme.of(context).colorScheme.primaryContainer : null, borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w700, color: current ? null : Colors.grey)), if (ev.isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(ev.length.clamp(0, 3), (_) => const Padding(padding: EdgeInsets.symmetric(horizontal: 1), child: CircleAvatar(radius: 3))))]))); })),
        Expanded(flex: 3, child: _eventsFor(_selectedDate).isEmpty ? Center(child: Text(ar ? 'لا توجد مناسبات رسمية في هذا اليوم' : 'No official events on this date')) : ListView(padding: const EdgeInsets.all(12), children: _eventsFor(_selectedDate).map((e) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.event_rounded)), title: Text(ar ? (e['title_ar']?.toString() ?? e['title_en']?.toString() ?? '') : (e['title_en']?.toString() ?? e['title_ar']?.toString() ?? '')), subtitle: Text([if ((e['time_text'] ?? '').toString().isNotEmpty) e['time_text'], if ((e['source_title'] ?? '').toString().isNotEmpty) e['source_title']].join(' • ')), trailing: IconButton(onPressed: () => _openSource(e['source_url']?.toString()), icon: const Icon(Icons.open_in_new_rounded))))).toList())),
        if (_lastSync != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(ar ? 'آخر تحديث من المصدر الرسمي: ${_lastSync!.replaceFirst('T', ' ').substring(0, 16)}' : 'Last official sync: ${_lastSync!.replaceFirst('T', ' ').substring(0, 16)}', style: const TextStyle(fontSize: 11, color: Colors.grey))),
      ]),
    ));
  }
}
