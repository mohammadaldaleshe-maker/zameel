import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_media_service.dart';

class RemainingServices {
  static final SupabaseClient _db = Supabase.instance.client;
  static String? get uid => _db.auth.currentUser?.id;

  static Future<List<Map<String, dynamic>>> calendarEvents() async {
    final me = uid;
    if (me == null) return [];
    final rows = await _db
        .from('calendar_events')
        .select('id,title,event_date,event_time,event_type,notes,created_at')
        .eq('owner_id', me)
        .order('event_date')
        .order('event_time');
    return _maps(rows);
  }

  static Future<Map<String, dynamic>> addCalendarEvent({
    required String title,
    required DateTime date,
    required String time,
    required String type,
  }) async {
    final me = uid;
    if (me == null) throw StateError('not_authenticated');
    final row = await _db
        .from('calendar_events')
        .insert({
          'owner_id': me,
          'title': title.trim(),
          'event_date': _dateOnly(date),
          'event_time': time.trim().isEmpty ? null : time.trim(),
          'event_type': type,
        })
        .select('id,title,event_date,event_time,event_type,notes,created_at')
        .single();
    return Map<String, dynamic>.from(row);
  }

  static Future<void> deleteCalendarEvent(String id) async {
    final me = uid;
    if (me == null || id.isEmpty) return;
    await _db.from('calendar_events').delete().eq('id', id).eq('owner_id', me);
  }

  static Future<List<Map<String, dynamic>>> groups() async {
    if (uid == null) return [];
    final rows = await _db.rpc('get_community_groups');
    return _maps(rows);
  }

  static Future<Map<String, dynamic>> createGroup({
    required String name,
    required String description,
    required String type,
    required bool isPrivate,
  }) async {
    final me = uid;
    if (me == null) throw StateError('not_authenticated');
    Map<String, dynamic>? profile;
    try {
      final value = await _db
          .from('users')
          .select('university,college,department')
          .eq('id', me)
          .maybeSingle();
      if (value != null) profile = Map<String, dynamic>.from(value);
    } catch (_) {}
    final row = await _db
        .from('community_groups')
        .insert({
          'owner_id': me,
          'name': name.trim(),
          'description': description.trim(),
          'group_type': type,
          'is_private': isPrivate,
          'university': profile?['university']?.toString() ?? '',
          'college': profile?['college']?.toString() ?? '',
          'department': profile?['department']?.toString() ?? '',
        })
        .select('id,owner_id,name,description,group_type,is_private,created_at')
        .single();
    final result = Map<String, dynamic>.from(row);
    result['members'] = 1;
    result['is_joined'] = true;
    result['is_owner'] = true;
    result['join_status'] = 'accepted';
    return result;
  }

  static Future<String> joinGroup(String groupId) async {
    if (uid == null || groupId.isEmpty) return 'unavailable';
    final result = await _db.rpc(
      'join_community_group',
      params: {'target_group_id': groupId},
    );
    return result?.toString() ?? 'joined';
  }

  static Future<List<Map<String, dynamic>>> groupJoinRequests(String groupId) async {
    if (uid == null || groupId.isEmpty) return [];
    final rows = await _db.rpc(
      'get_community_group_join_requests',
      params: {'target_group_id': groupId},
    );
    return _maps(rows);
  }

  static Future<void> respondGroupJoinRequest(
    String requestId, {
    required bool accept,
  }) async {
    if (uid == null || requestId.isEmpty) return;
    await _db.rpc(
      'respond_community_group_join_request',
      params: {
        'target_request_id': requestId,
        'accept_request': accept,
      },
    );
  }

  static Future<void> leaveGroup(String groupId) async {
    if (uid == null || groupId.isEmpty) return;
    await _db.rpc('leave_community_group', params: {'target_group_id': groupId});
  }

  static Future<void> deleteGroup(String groupId) async {
    if (uid == null || groupId.isEmpty) return;
    await _db.rpc('delete_community_group', params: {'target_group_id': groupId});
  }

  static Future<List<Map<String, dynamic>>> groupMessages(String groupId) async {
    if (uid == null || groupId.isEmpty) return [];
    final rows = await _db.rpc(
      'get_community_group_messages',
      params: {'target_group_id': groupId},
    );
    return _maps(rows);
  }

  static Future<void> sendGroupMessage(String groupId, String content) async {
    final me = uid;
    if (me == null || groupId.isEmpty || content.trim().isEmpty) return;
    await _db.from('community_group_messages').insert({
      'group_id': groupId,
      'user_id': me,
      'content': content.trim(),
    });
  }

  static RealtimeChannel subscribeToGroupMessages(
    String groupId,
    void Function() onChange,
  ) {
    return _db
        .channel('community_group_messages:$groupId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_group_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: groupId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  static Future<void> removeChannel(RealtimeChannel? channel) async {
    if (channel == null) return;
    await _db.removeChannel(channel);
  }

  static Future<List<Map<String, dynamic>>> polls() async {
    if (uid == null) return [];
    final rows = await _db.rpc('get_polls');
    return _maps(rows);
  }

  static Future<void> createPoll(String question, List<String> options) async {
    if (uid == null) return;
    await _db.rpc('create_poll', params: {
      'target_question': question.trim(),
      'target_options': options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    });
  }

  static Future<void> votePoll(String pollId, String optionId) async {
    if (uid == null) return;
    await _db.rpc('vote_poll', params: {
      'target_poll_id': pollId,
      'target_option_id': optionId,
    });
  }

  static Future<void> deletePoll(String pollId) async {
    if (uid == null || pollId.isEmpty) return;
    await _db.rpc('delete_poll', params: {'target_poll_id': pollId});
  }

  static Future<List<Map<String, dynamic>>> anonymousMessages() async {
    if (uid == null) return [];
    final rows = await _db.rpc('get_anonymous_messages', params: {'result_limit': 100});
    return _maps(rows);
  }

  static Future<void> sendAnonymousMessage(String content) async {
    if (uid == null || content.trim().isEmpty) return;
    await _db.rpc('send_anonymous_message', params: {'target_content': content.trim()});
  }

  static Future<List<Map<String, dynamic>>> partners() async {
    if (uid == null) return [];
    final rows = await _db
        .from('business_partners')
        .select('id,name,category,tag,description,website_url,logo_url,is_approved,created_at')
        .eq('is_approved', true)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return _maps(rows);
  }

  static Future<bool> canManagePartners() async {
    if (uid == null) return false;
    final result = await _db.rpc('is_zameel_owner', params: {'target_user_id': uid});
    return result == true;
  }

  static Future<void> addPartner({
    required String name,
    required String category,
    required String tag,
    required String description,
    String? websiteUrl,
  }) async {
    if (uid == null) return;
    await _db.rpc('admin_add_business_partner', params: {
      'target_name': name.trim(),
      'target_category': category,
      'target_tag': tag.trim(),
      'target_description': description.trim(),
      'target_website_url': websiteUrl?.trim(),
      'target_logo_url': null,
    });
  }

  static Future<void> deletePartner(String partnerId) async {
    if (uid == null || partnerId.isEmpty) return;
    await _db.rpc('admin_delete_business_partner', params: {'target_partner_id': partnerId});
  }

  static Future<Map<String, dynamic>> activityStats() async {
    if (uid == null) return {};
    final raw = await _db.rpc('get_my_activity_stats');
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  static Future<List<Map<String, dynamic>>> weeklyActivity() async {
    if (uid == null) return [];
    final rows = await _db.rpc('get_my_weekly_activity');
    return _maps(rows);
  }

  static Future<List<Map<String, dynamic>>> savedPosts() async {
    final me = uid;
    if (me == null) return [];
    final rows = await _db
        .from('saved_posts')
        .select('post_id,created_at,posts(*,users(name,profile_image))')
        .eq('user_id', me)
        .order('created_at', ascending: false);
    final result = <Map<String, dynamic>>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final post = row['posts'];
      if (post is Map) {
        result.add({...Map<String, dynamic>.from(post), 'saved_at': row['created_at']});
      }
    }
    await SecureMediaService.resolvePosts(result);
    return result;
  }

  static Future<void> unsavePost(String postId) async {
    final me = uid;
    if (me == null || postId.isEmpty) return;
    await _db.from('saved_posts').delete().eq('user_id', me).eq('post_id', postId);
  }

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static String _dateOnly(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
