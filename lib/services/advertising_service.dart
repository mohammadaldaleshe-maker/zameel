import 'package:supabase_flutter/supabase_flutter.dart';

import 'feature_control.dart';

class AdvertisingService {
  static final _db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> liveAds({
    String? partnerId,
    String? query,
    int limit = 12,
  }) async {
    if (!FeatureControl.instance.enabled('partner_advertising')) return [];
    final response = await _db.functions.invoke('advertising-console', body: {
      'action': 'public_feed',
      'limit': limit,
      if (partnerId != null) 'partner_id': partnerId,
      if (query != null) 'query': query,
    });
    final data = response.data;
    if (data is! Map || data['rows'] is! List) return [];
    return (data['rows'] as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Future<void> recordView(String id) async {
    await _db.rpc('record_advertisement_view', params: {'target_ad_id': id});
  }

  static Future<void> hide(String id) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('advertisement_hides').upsert({
      'advertisement_id': id, 'user_id': uid,
    });
  }

  static Future<bool> isLiked(String id) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _db.from('advertisement_likes').select('advertisement_id')
        .eq('advertisement_id', id).eq('user_id', uid).maybeSingle();
    return row != null;
  }

  static Future<void> setLiked(String id, {required bool liked}) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    if (liked) {
      await _db.from('advertisement_likes').insert({
        'advertisement_id': id, 'user_id': uid,
      });
    } else {
      await _db.from('advertisement_likes').delete()
          .eq('advertisement_id', id).eq('user_id', uid);
    }
  }

  static Future<List<Map<String, dynamic>>> comments(String id) async {
    final rows = await _db.from('advertisement_comments')
        .select('id,author_id,parent_id,body,created_at')
        .eq('advertisement_id', id)
        .order('created_at', ascending: true)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> comment(String id, String body) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null || body.trim().isEmpty) return;
    await _db.from('advertisement_comments').insert({
      'advertisement_id': id, 'author_id': uid, 'body': body.trim(),
    });
  }
}
