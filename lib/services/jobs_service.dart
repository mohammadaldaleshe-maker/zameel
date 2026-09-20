import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/theme/app_theme.dart';

class JobsService {
  static final _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> search({
    String query = '',
    String location = 'Jordan',
    int results = 30,
  }) async {
    try {
      final response = await _client.functions.invoke('jobs-search', body: {
        'q': query,
        'location': location,
        'results': results,
      });
      final raw = response.data;
      if (raw is Map && raw['jobs'] is List) {
        return _normalizeList(raw['jobs'] as List);
      }
    } catch (_) {}

    // Free public fallback so Jobs remains useful during an Edge outage.
    try {
      final response = await http.get(
        Uri.parse('https://www.arbeitnow.com/api/job-board-api'),
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Zameel/2.0'
        },
      );
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        final items =
            raw is Map && raw['data'] is List ? raw['data'] as List : const [];
        final q = query.trim().toLowerCase();
        return _normalizeList(items
            .whereType<Map>()
            .where((job) {
              final text =
                  '${job['title'] ?? ''} ${job['company_name'] ?? ''} ${job['description'] ?? ''} ${job['location'] ?? ''}'
                      .toLowerCase();
              return q.isEmpty || text.contains(q);
            })
            .take(results)
            .map((job) => {
                  'id': job['slug']?.toString() ?? job['id']?.toString(),
                  'title_en': job['title']?.toString() ?? '',
                  'title_ar': job['title']?.toString() ?? '',
                  'company': job['company_name']?.toString() ?? '',
                  'type_en': job['job_types'] is List
                      ? (job['job_types'] as List).join(', ')
                      : 'Job',
                  'type_ar': _arabicType(job['job_types']),
                  'location_en': job['location']?.toString() ?? location,
                  'location_ar': job['location']?.toString() ?? location,
                  'description_en': job['description']?.toString() ?? '',
                  'description_ar': job['description']?.toString() ?? '',
                  'url': job['url']?.toString() ?? '',
                  'created_at': job['created_at']?.toString() ?? '',
                  'isRemote': job['remote'] == true,
                  'provider': 'Arbeitnow',
                }));
      }
    } catch (_) {}
    return [];
  }

  static Future<void> setSaved(Map<String, dynamic> job, bool saved) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final externalJobId = externalId(job);
    if (saved) {
      await _client.from('saved_job_opportunities').upsert({
        'user_id': userId,
        'external_id': externalJobId,
        'job_snapshot': _jsonSafeJob(job),
      });
    } else {
      await _client
          .from('saved_job_opportunities')
          .delete()
          .eq('user_id', userId)
          .eq('external_id', externalJobId);
    }
  }

  static Future<Set<String>> savedIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final rows = await _client
          .from('saved_job_opportunities')
          .select('external_id')
          .eq('user_id', userId);
      return (rows as List)
          .map((row) => row['external_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> recordApplication(Map<String, dynamic> job) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('job_applications').upsert({
      'user_id': userId,
      'external_id': externalId(job),
      'job_snapshot': _jsonSafeJob(job),
      'status': 'opened',
      'applied_at': DateTime.now().toIso8601String(),
    });
  }

  static Uri linkedInJobsUri({String query = '', String location = 'Jordan'}) {
    return Uri.https('www.linkedin.com', '/jobs/search/', {
      if (query.trim().isNotEmpty) 'keywords': query.trim(),
      'location': location.trim().isEmpty ? 'Jordan' : location.trim(),
    });
  }

  static String externalId(Map<String, dynamic> job) {
    final id = job['id']?.toString().trim();
    if (id != null && id.isNotEmpty) return id;
    return '${job['provider'] ?? 'zameel'}:${job['company'] ?? ''}:${job['title_en'] ?? job['title_ar'] ?? ''}';
  }

  static Map<String, dynamic> _jsonSafeJob(Map<String, dynamic> job) {
    final copy = Map<String, dynamic>.from(job)..remove('color');
    return jsonDecode(jsonEncode(copy)) as Map<String, dynamic>;
  }

  static List<Map<String, dynamic>> _normalizeList(Iterable raw) {
    return raw.whereType<Map>().map((item) {
      final job = Map<String, dynamic>.from(item);
      job['id'] ??= externalId(job);
      job['title_ar'] ??= job['title_en'] ?? '';
      job['title_en'] ??= job['title_ar'] ?? '';
      job['company'] ??= '';
      job['type_ar'] ??= _arabicType(job['type_en']);
      job['type_en'] ??= 'Job';
      job['location_ar'] ??= job['location_en'] ?? 'Jordan';
      job['location_en'] ??= job['location_ar'] ?? 'Jordan';
      job['description_ar'] ??= job['description_en'] ?? '';
      job['description_en'] ??= job['description_ar'] ?? '';
      job['requirements_ar'] ??= '';
      job['requirements_en'] ??= '';
      job['salary'] ??= 'غير محدد';
      job['deadline'] ??= 'مفتوح';
      job['isRemote'] ??= false;
      job['isUrgent'] ??= false;
      job['color'] = AppTheme.primary;
      return job;
    }).toList();
  }

  static String _arabicType(dynamic value) {
    final text = value is List ? value.join(' ') : value?.toString() ?? '';
    return RegExp(r'intern|trainee|training', caseSensitive: false)
            .hasMatch(text)
        ? 'تدريب'
        : 'وظيفة';
  }
}
