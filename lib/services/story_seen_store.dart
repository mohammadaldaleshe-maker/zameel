import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-account, bounded viewed IDs. Does not store story text/media or user profiles.
class StorySeenStore {
  static String _key(String uid) => 'zameel_seen_stories153:$uid';
  static Future<Set<String>> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final rows = jsonDecode(prefs.getString(_key(uid)) ?? '{}') as Map;
      final now = DateTime.now().millisecondsSinceEpoch;
      return rows.entries
          .where((e) => e.value is num && (e.value as num) > now)
          .map((e) => '${e.key}')
          .toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(String uid, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load(uid);
    final union = {...existing, ...ids}.toList();
    final cutoff =
        DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch;
    final bounded = union.skip(union.length > 2000 ? union.length - 2000 : 0);
    await prefs.setString(
        _key(uid), jsonEncode({for (final id in bounded) id: cutoff}));
  }
}
