import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../friends/friends_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  SupabaseClient get db => Supabase.instance.client;
  String? get uid => db.auth.currentUser?.id;
  List<Map<String,dynamic>> _items=[];
  bool _loading=true;
  int get _unread=>_items.where((e)=>e['is_read']==false).length;

  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    if(uid==null)return;
    try{final rows=await db.from('notifications').select('*, actor:users!notifications_actor_id_fkey(id,name,profile_image)').eq('user_id',uid!).order('created_at',ascending:false).limit(100);if(mounted)setState(()=>_items=List<Map<String,dynamic>>.from(rows));}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحميل الإشعارات: $e')));}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Future<void> _read(Map<String,dynamic> n) async { if(n['is_read']==true)return; try{await db.from('notifications').update({'is_read':true}).eq('id',n['id']);if(mounted)setState(()=>n['is_read']=true);}catch(_){}}
  Future<void> _markAll() async { try{await db.from('notifications').update({'is_read':true}).eq('user_id',uid!);await _load();}catch(_){}}
  Future<void> _clear() async { try{await db.from('notifications').delete().eq('user_id',uid!);await _load();}catch(_){}}

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;

    return Directionality(
      textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
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
                            : type == 'like'
                                ? Icons.favorite_rounded
                                : type == 'comment'
                                    ? Icons.comment_rounded
                                    : Icons.notifications_rounded;
                        final color = const Color(0xFF18D3C3);

                        return Card(
                          color: n['is_read'] == true
                              ? Colors.white
                              : const Color(0xFFE1FBF8),
                          child: ListTile(
                            onTap: () async {
                              await _read(n);
                              if (!mounted) return;
                              if (type.startsWith('friend_request')) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const FriendsScreen(),
                                  ),
                                );
                              }
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
                                    color: Color(0xFF18D3C3),
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
