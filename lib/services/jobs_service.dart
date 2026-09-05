import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class JobsService {
  static Future<List<Map<String, dynamic>>> search({String query = '', String location = 'Jordan', int results = 20}) async {
    try {
      final response = await Supabase.instance.client.functions.invoke('jobs-search', body: {'q': query, 'location': location, 'results': results});
      final raw = response.data;
      if (raw is Map && raw['jobs'] is List && (raw['jobs'] as List).isNotEmpty) {
        return (raw['jobs'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    // Public fallback: current Arbeitnow free Job Board API, no API key.
    try {
      final uri = Uri.parse('https://www.arbeitnow.com/api/job-board-api');
      final response = await http.get(uri, headers: {'Accept': 'application/json', 'User-Agent': 'Zameel/1.3.7'});
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        final items = raw is Map && raw['data'] is List ? raw['data'] as List : const [];
        final q = query.trim().toLowerCase();
        return items.whereType<Map>().where((j) {
          final hay = '${j['title'] ?? ''} ${j['company_name'] ?? ''} ${j['description'] ?? ''} ${j['location'] ?? ''}'.toLowerCase();
          return q.isEmpty || hay.contains(q);
        }).take(results).map((j) => <String, dynamic>{
          'id': j['slug']?.toString() ?? j['id']?.toString(),
          'title_en': j['title']?.toString() ?? '',
          'title_ar': j['title']?.toString() ?? '',
          'company': j['company_name']?.toString() ?? '',
          'type_en': j['job_types'] is List ? (j['job_types'] as List).join(', ') : 'Job',
          'type_ar': 'وظيفة',
          'location_en': j['location']?.toString() ?? location,
          'location_ar': j['location']?.toString() ?? location,
          'description_en': j['description']?.toString() ?? '',
          'description_ar': j['description']?.toString() ?? '',
          'url': j['url']?.toString() ?? '',
          'created_at': j['created_at']?.toString() ?? '',
          'isRemote': j['remote'] == true,
          'color': 0xFF18D4C6,
          'provider': 'Arbeitnow',
        }).toList();
      }
    } catch (_) {}
    return [];
  }
}
