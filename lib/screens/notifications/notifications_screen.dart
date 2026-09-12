import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../friends/friends_screen.dart';
import '../meet/meet_screen.dart';
import '../comments/comments_screen.dart';
import '../chat/chat_screen.dart';
import '../stories/stories_screen.dart';
import 'package:zameel/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  SupabaseClient get db => Supabase.instance.client;
  String? get uid => db.auth.currentUser?.id;
  List<Map<String,dynamic>> _items=[];
  bool _loading=true;
  RealtimeChannel? _notificationsChannel;
  Timer? _reloadDebounce;
  int get _unread=>_items.where((e)=>e['is_read']==false).length;

  @override
  void initState(){
    super.initState();
    _load();
    _subscribeNotifications();
  }

  void _subscribeNotifications() {
    final me = uid;
    if (me == null) return;
    _notificationsChannel = db.channel('zameel-notifications-screen:$me');
    _notificationsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: me,
          ),
          callback: (_) {
            _reloadDebounce?.cancel();
            _reloadDebounce = Timer(const Duration(milliseconds: 180), _load);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }
  Future<void> _load() async {
    if(uid==null)return;
    try{final rows=await db.from('notifications').select('*, actor:users!notifications_actor_id_fkey(id,name,profile_image)').eq('user_id',uid!).order('created_at',ascending:false).limit(100);if(mounted)setState(()=>_items=List<Map<String,dynamic>>.from(rows));}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحميل الإشعارات: $e')));}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Future<void> _read(Map<String,dynamic> n) async { if(n['is_read']==true)return; try{await db.from('notifications').update({'is_read':true}).eq('id',n['id']);if(mounted)setState(()=>n['is_read']=true);}catch(_){}}
  Future<void> _markAll() async { try{await db.from('notifications').update({'is_read':true}).eq('user_id',uid!);await _load();}catch(_){}}
  Future<void> _clear() async { try{await db.from('notifications').delete().eq('user_id',uid!);await _load();}catch(_){}}

  Map<String, dynamic> _notificationData(Map<String, dynamic> n) {
    final raw = n['data'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  Future<void> _openIncomingCall(Map<String, dynamic> n) async {
    final data = _notificationData(n);
    final roomId = data['room_id']?.toString() ?? '';
    if (roomId.isEmpty) return;
    final type = n['type']?.toString() ?? '';
    final video = data['video'] == true ||
        data['video']?.toString().toLowerCase() == 'true' ||
        type == 'incoming_video_call';
    final actor = n['actor'];
    final callerName = actor is Map && actor['name']?.toString().trim().isNotEmpty == true
        ? actor['name'].toString()
        : 'Colleague';
    await _read(n);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetScreen(
          participantName: callerName,
          roomId: roomId,
          startImmediately: true,
          startWithVideo: video,
          isInitiator: false,
        ),
      ),
    );
  }


  Future<void> _openNotificationSource(Map<String, dynamic> n) async {
    final type = n['type']?.toString() ?? '';
    final data = _notificationData(n);
    if (type.startsWith('friend_request')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen(initialTab: 1)));
      return;
    }
    if (type == 'incoming_video_call' || type == 'incoming_voice_call') {
      await _openIncomingCall(n);
      return;
    }
    final postId = (data['post_id'] ?? data['target_post_id'])?.toString() ?? '';
    if (postId.isNotEmpty) {
      try {
        final post = await db.from('posts').select('*, users(name,profile_image,gender,role,university,college,department)').eq('id', postId).maybeSingle();
        if (post != null && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsScreen(post: Map<String, dynamic>.from(post))));
          return;
        }
      } catch (_) {}
    }
    final conversationId = data['conversation_id']?.toString() ?? '';
    final actorId = n['actor_id']?.toString() ?? data['sender_id']?.toString() ?? '';
    if (conversationId.isNotEmpty && actorId.isNotEmpty) {
      final actor = n['actor'];
      final name = actor is Map ? actor['name']?.toString() : null;
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(conversationId: conversationId, partnerId: actorId, partnerName: name?.trim().isNotEmpty == true ? name! : 'Colleague')));
      }
      return;
    }
    final storyId = data['story_id']?.toString() ?? '';
    if (storyId.isNotEmpty && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: StoriesWidget()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;

    return Directionality(
      textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: AppBar(
          title: Text(
            ar ? '🔔 الإشعارات ($_unread)' : '🔔 Notifications ($_unread)',
          ),
          actions: [
            IconButton(
              onPressed: _markAll,
              icon: const Icon(Icons.done_all_rounded),
            ),
            IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(
                    child: Text(
                      ar
                          ? 'لا توجد إشعارات بعد'
                          : 'No notifications yet',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final n = _items[i];
                        final type = n['type']?.toString() ?? '';
                        final icon = type.startsWith('friend_request')
                            ? Icons.person_add_alt_1_rounded
                            : type == 'incoming_video_call'
                                ? Icons.videocam_rounded
                                : type == 'incoming_voice_call'
                                    ? Icons.call_rounded
                                    : type == 'like'
                                        ? Icons.favorite_rounded
                                        : type == 'comment'
                                            ? Icons.comment_rounded
                                            : Icons.notifications_rounded;
                        final color = AppTheme.primary;

                        return Card(
                          color: n['is_read'] == true
                              ? Colors.white
                              : AppTheme.accentSoft,
                          child: ListTile(
                            onTap: () async {
                              await _read(n);
                              if (!mounted) return;
                              await _openNotificationSource(n);
                            },
                            leading: CircleAvatar(
                              backgroundColor: color.withAlpha(25),
                              child: Icon(icon, color: color),
                            ),
                            title: Text(
                              ((ar
                                          ? n['title_ar']
                                          : n['title_en'])
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true)
                                  ? (ar
                                      ? n['title_ar'].toString()
                                      : n['title_en'].toString())
                                  : (n['message']?.toString() ?? ''),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              ((ar
                                          ? n['body_ar']
                                          : n['body_en'])
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true)
                                  ? (ar
                                      ? n['body_ar'].toString()
                                      : n['body_en'].toString())
                                  : (n['type']?.toString() ?? ''),
                            ),
                            trailing: n['is_read'] == true
                                ? null
                                : const Icon(
                                    Icons.circle,
                                    size: 9,
                                    color: AppTheme.primary,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
