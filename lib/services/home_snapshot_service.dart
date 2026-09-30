import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local previews only. Server authorization still governs every request.
/// No friends-only stories or private clips are persisted by this service.
class HomeSnapshotService {
  HomeSnapshotService._();
  static const lifetime = Duration(hours: 6);
  static const _sections = ['stories', 'clips', 'ads', 'profile'];
  static final Map<String, int> _epochs = {};
  static String _key(String userId, String section) =>
      'zameel_home_v123_${userId}_$section';

  static bool _future(dynamic value, DateTime now) =>
      DateTime.tryParse(value?.toString() ?? '')?.isAfter(now) == true;

  static bool _allowed(String section, Map<String, dynamic> row, DateTime now) {
    if (section == 'stories') {
      return row['audience'] == 'public' && _future(row['expires_at'], now);
    }
    if (section == 'clips') {
      return row['audience'] == 'public' && row['is_hidden'] != true;
    }
    if (section == 'ads') {
      return row['status'] == 'published' && row['deleted_at'] == null &&
          _future(row['expires_at'], now);
    }
    return section == 'profile' && row['onboarding_complete'] == true;
  }

  static Future<List<Map<String, dynamic>>> read(String userId, String section) async {
    if (userId.isEmpty || !_sections.contains(section)) return [];
    final epoch = _epochs[userId] ?? 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId, section));
      if (raw == null || epoch != (_epochs[userId] ?? 0)) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['rows'] is! List) return [];
      final now = DateTime.now();
      final saved = DateTime.tryParse(decoded['saved_at']?.toString() ?? '');
      if (saved == null || saved.isAfter(now) || now.difference(saved) >= lifetime) {
        await prefs.remove(_key(userId, section));
        return [];
      }
      return (decoded['rows'] as List).whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) => _allowed(section, row, now)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String userId, String section,
      List<Map<String, dynamic>> rows) async {
    if (userId.isEmpty || !_sections.contains(section)) return;
    final epoch = _epochs[userId] ?? 0;
    try {
      final now = DateTime.now();
      final encoded = jsonEncode({
        'saved_at': now.toIso8601String(),
        'rows': rows.where((row) => _allowed(section, row, now)).toList(),
      });
      final prefs = await SharedPreferences.getInstance();
      if (epoch != (_epochs[userId] ?? 0)) return;
      await prefs.setString(_key(userId, section), encoded);
    } catch (_) {
      // A full disk or unavailable browser storage must not break live data.
    }
  }

  static Future<void> clear(String userId, {String? section}) async {
    _epochs[userId] = (_epochs[userId] ?? 0) + 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final name in section == null ? _sections : [section]) {
        await prefs.remove(_key(userId, name));
      }
    } catch (_) {}
  }
}
