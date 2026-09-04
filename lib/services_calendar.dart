import 'package:supabase_flutter/supabase_flutter.dart';

class ZameelCalendarService {
  static final db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> load(String universityKey) async {
    final cached = await db.from('university_calendar_events').select().eq('university_key', universityKey).order('event_date');
    return List<Map<String, dynamic>>.from(cached);
  }

  static Future<List<Map<String, dynamic>>> loadFresh(String universityKey, {Duration maxAge = const Duration(hours: 12)}) async {
    final rows = await load(universityKey);
    if (rows.isEmpty) return sync(universityKey);
    final fetched = rows.map((e) => DateTime.tryParse(e['fetched_at']?.toString() ?? '')).whereType<DateTime>().fold<DateTime?>(null, (a,b) => a == null || b.isAfter(a) ? b : a);
    if (fetched == null || DateTime.now().toUtc().difference(fetched) > maxAge) { try { return await sync(universityKey); } catch (_) {} }
    return rows;
  }

  static Future<List<Map<String, dynamic>>> sync(String universityKey) async {
    final result = await db.functions.invoke('university-calendar', body: {'university_key': universityKey});
    final data = result.data;
    if (data is! Map) throw Exception('Calendar sync failed');
    final events = List<Map<String, dynamic>>.from((data['events'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    if (events.isEmpty) return load(universityKey);
    await db.from('university_calendar_events').delete().eq('university_key', universityKey);
    final rows = events.map((e) => {
      'university_key': universityKey,
      'university_name': data['university_name'] ?? universityKey,
      'title_ar': e['title_ar'],
      'title_en': e['title_en'],
      'event_date': e['event_date'],
      'end_date': e['end_date'],
      'time_text': e['time_text'],
      'source_url': e['source_url'],
      'source_title': e['source_title'],
      'fetched_at': data['fetched_at'] ?? DateTime.now().toUtc().toIso8601String(),
    }).toList();
    await db.from('university_calendar_events').insert(rows);
    return load(universityKey);
  }
}
