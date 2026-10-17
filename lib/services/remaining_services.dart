import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'feature_control.dart';
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

  static Future<List<Map<String, dynamic>>> groupJoinRequests(
      String groupId) async {
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
    await _db
        .rpc('leave_community_group', params: {'target_group_id': groupId});
  }

  static Future<void> deleteGroup(String groupId) async {
    if (uid == null || groupId.isEmpty) return;
    await _db
        .rpc('delete_community_group', params: {'target_group_id': groupId});
  }

  static Future<List<Map<String, dynamic>>> groupMessages(
      String groupId) async {
    if (uid == null || groupId.isEmpty) return [];
    final rows = await _db.rpc(
      'get_community_group_messages_155',
      params: {'target_group_id': groupId},
    );
    return _maps(rows);
  }

  static Future<void> sendGroupMessage(
    String groupId,
    String content, {
    String? mediaPath,
    String? mediaType,
  }) async {
    final me = uid;
    if (me == null || groupId.isEmpty || content.trim().isEmpty) return;
    final row = <String, dynamic>{
      'group_id': groupId,
      'user_id': me,
      'content': content.trim(),
    };
    if (mediaPath != null && mediaType != null) {
      row['media_url'] = mediaPath;
      row['media_type'] = mediaType;
    }
    await _db.from('community_group_messages').insert(row);
  }

  /// Uploads one chat attachment to the private group bucket and returns its
  /// path (`<my id>/<group id>/<file>`), which is what the message stores.
  static Future<String> uploadGroupAttachment(
    String groupId,
    Uint8List bytes,
    String filename,
    String contentType,
  ) async {
    final me = uid;
    if (me == null || groupId.isEmpty) throw StateError('not_authenticated');
    final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$me/$groupId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _db.storage.from('group_media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return path;
  }

  static final Map<String, String> _groupMediaUrls = {};

  static String? cachedGroupAttachmentUrl(String path) =>
      _groupMediaUrls[path];

  static Future<String?> groupAttachmentUrl(String path) async {
    final cached = _groupMediaUrls[path];
    if (cached != null) return cached;
    try {
      final url =
          await _db.storage.from('group_media').createSignedUrl(path, 3600);
      _groupMediaUrls[path] = url;
      return url;
    } catch (_) {
      return null;
    }
  }

  // ---- members, invitations and invite link (migration 166) ----------------

  static Future<List<Map<String, dynamic>>> groupMembers(
      String groupId) async {
    if (uid == null || groupId.isEmpty) return [];
    final rows = await _db.rpc(
      'get_community_group_members',
      params: {'target_group_id': groupId},
    );
    return _maps(rows);
  }

  static Future<void> removeGroupMember(String groupId, String userId) async {
    if (uid == null || groupId.isEmpty || userId.isEmpty) return;
    await _db.rpc('kick_community_group_member', params: {
      'target_group_id': groupId,
      'target_user_id': userId,
    });
  }

  static const String groupLinkPrefix = 'https://zameeljo.com/s/group/';

  static Future<String> groupInviteLink(String groupId) async {
    final code = await _db.rpc(
      'get_community_group_invite_code',
      params: {'target_group_id': groupId},
    );
    return '$groupLinkPrefix$code';
  }

  static Future<String> resetGroupInviteLink(String groupId) async {
    final code = await _db.rpc(
      'reset_community_group_invite_code',
      params: {'target_group_id': groupId},
    );
    return '$groupLinkPrefix$code';
  }

  /// Accepts a full link or a bare code and returns the lower-case code.
  static String groupCodeFromText(String text) {
    var value = text.trim();
    final query = value.indexOf('?');
    if (query >= 0) value = value.substring(0, query);
    final parts = value.split('/').where((e) => e.trim().isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts.last.trim().toLowerCase();
  }

  static Future<Map<String, dynamic>?> groupByInviteCode(String code) async {
    if (uid == null || code.isEmpty) return null;
    final rows = await _db.rpc(
      'get_community_group_by_invite_code',
      params: {'target_code': code},
    );
    final list = _maps(rows);
    return list.isEmpty ? null : list.first;
  }

  static Future<String> joinGroupByCode(String code) async {
    final result = await _db.rpc(
      'join_community_group_by_code',
      params: {'target_code': code},
    );
    return result?.toString() ?? '';
  }

  /// The people the user can invite: his accepted colleagues.
  static Future<List<Map<String, dynamic>>> colleaguesToInvite() async {
    final me = uid;
    if (me == null) return [];
    final requests = await _db
        .from('friend_requests')
        .select('sender_id,receiver_id')
        .eq('status', 'accepted')
        .or('sender_id.eq.$me,receiver_id.eq.$me');
    final ids = <String>{};
    for (final row in _maps(requests)) {
      final sender = row['sender_id']?.toString() ?? '';
      final receiver = row['receiver_id']?.toString() ?? '';
      final other = sender == me ? receiver : sender;
      if (other.isNotEmpty && other != me) ids.add(other);
    }
    if (ids.isEmpty) return [];
    final users = await _db
        .from('users')
        .select('id,name,profile_image')
        .inFilter('id', ids.toList());
    final list = _maps(users);
    list.sort((a, b) =>
        (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
    return list;
  }

  /// Returns `sent`, `already_invited` or `already_member`.
  static Future<String> sendGroupInvitation(
      String groupId, String userId) async {
    final result = await _db.rpc('send_community_group_invitation', params: {
      'target_group_id': groupId,
      'target_user_id': userId,
    });
    return result?.toString() ?? 'sent';
  }

  static Future<List<Map<String, dynamic>>> myGroupInvitations() async {
    if (uid == null) return [];
    final rows = await _db.rpc('get_my_community_group_invitations');
    return _maps(rows);
  }

  static Future<Map<String, dynamic>?> groupInvitation(
      String invitationId) async {
    if (uid == null || invitationId.isEmpty) return null;
    final rows = await _db.rpc(
      'get_community_group_invitation',
      params: {'target_invitation_id': invitationId},
    );
    final list = _maps(rows);
    return list.isEmpty ? null : list.first;
  }

  /// Returns the id of the group the invitation was for.
  static Future<String> respondGroupInvitation(String invitationId,
      {required bool accept}) async {
    final result = await _db.rpc('respond_community_group_invitation', params: {
      'target_invitation_id': invitationId,
      'accept_invitation': accept,
    });
    return result?.toString() ?? '';
  }

  /// Arabic text for the refusal codes raised by the group functions.
  static String groupErrorText(Object error, String fallback) {
    final text = error.toString();
    const known = <String, String>{
      'removed_from_group': 'تم إخراجك من هذه المجموعة ولا يمكنك الانضمام إليها',
      'colleague_required': 'يمكنك دعوة زملائك فقط',
      'user_unavailable': 'لا يمكن دعوة هذا المستخدم',
      'too_many_invitations': 'أرسلت دعوات كثيرة، حاول بعد قليل',
      'group_membership_required': 'يجب أن تكون عضواً في المجموعة',
      'group_owner_required': 'هذا الإجراء لمالك المجموعة فقط',
      'cannot_remove_owner': 'لا يمكن إخراج مالك المجموعة',
      'invite_not_found': 'رابط الدعوة غير صالح أو تم تغييره',
      'pending_invitation_not_found': 'هذه الدعوة لم تعد متاحة',
    };
    for (final entry in known.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return FeatureControl.errorMessage(error, fallback);
  }

  static RealtimeChannel subscribeToGroupMessages(
      String groupId, void Function() onChange) {
    final channel = _db.channel('community_group_messages:$groupId');
    for (final event in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update
    ]) {
      channel.onPostgresChanges(
          event: event,
          schema: 'public',
          table: 'community_group_messages',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'group_id',
              value: groupId),
          callback: (_) => onChange());
    }
    return channel.subscribe();
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
      'target_options':
          options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
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
    final rows =
        await _db.rpc('get_anonymous_messages', params: {'result_limit': 100});
    return _maps(rows);
  }

  static Future<void> sendAnonymousMessage(String content) async {
    if (uid == null || content.trim().isEmpty) return;
    await _db.rpc('send_anonymous_message',
        params: {'target_content': content.trim()});
  }

  static Future<List<Map<String, dynamic>>> partners() async {
    if (uid == null) return [];
    final output = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += 200) {
      final rows = await _db
          .from('business_partners')
          .select(
              'id,name,category,tag,description,website_url,logo_url,is_approved,created_at,latitude,longitude,contact_phone,contact_email')
          .eq('is_approved', true)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      output.addAll(_maps(rows));
      if (rows.length < 200) break;
    }
    return output;
  }

  static Future<bool> canManagePartners() async {
    if (uid == null) return false;
    final result =
        await _db.rpc('is_zameel_owner', params: {'target_user_id': uid});
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
    await _db.rpc('admin_delete_business_partner',
        params: {'target_partner_id': partnerId});
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
        result.add({
          ...Map<String, dynamic>.from(post),
          'saved_at': row['created_at']
        });
      }
    }
    await SecureMediaService.resolvePosts(result);
    return result;
  }

  static Future<void> unsavePost(String postId) async {
    final me = uid;
    if (me == null || postId.isEmpty) return;
    await _db
        .from('saved_posts')
        .delete()
        .eq('user_id', me)
        .eq('post_id', postId);
  }

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static String _dateOnly(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
