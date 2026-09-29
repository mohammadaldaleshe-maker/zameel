import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A short-lived, account-scoped preview of public feed posts for cold starts.
/// Private and friends-only posts are deliberately never written to preferences.
class FeedSnapshotService {
  FeedSnapshotService._();

  static const _lifetime = Duration(hours: 6);
  static String _key(String userId) => 'zameel_public_feed_v1_$userId';

  static Future<List<Map<String, dynamic>>> read(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null) return [];
      final value = jsonDecode(raw);
      if (value is! Map) return [];
      final savedAt = DateTime.tryParse(value['saved_at']?.toString() ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt) > _lifetime ||
          savedAt.isAfter(DateTime.now())) {
        await prefs.remove(_key(userId));
        return [];
      }
      final rows = value['posts'];
      if (rows is! List) return [];
      return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row))
          .where((row) => row['audience']?.toString() == 'public')
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String userId, List<Map<String, dynamic>> posts) async {
    if (userId.isEmpty) return;
    try {
      final publicPosts = posts.where((row) =>
          row['audience']?.toString() == 'public').toList();
      final encoded = jsonEncode({
        'saved_at': DateTime.now().toIso8601String(),
        'posts': publicPosts,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(userId), encoded);
    } catch (_) {}
  }

  static Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}
