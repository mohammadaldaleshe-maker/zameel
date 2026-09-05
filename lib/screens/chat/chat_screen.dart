import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../anonymous/anonymous_screen.dart';
import '../meet/meet_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? partnerId;
  final String? partnerName;
  const ChatScreen({super.key, this.partnerId, this.partnerName});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  SupabaseClient get db => Supabase.instance.client;
  String? get uid => db.auth.currentUser?.id;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (uid == null) return;
    try {
      final me = uid!;
      final req = await db.from('friend_requests').select('id,sender_id,receiver_id,status,sender:users!friend_requests_sender_id_fkey(id,name,profile_image),receiver:users!friend_requests_receiver_id_fkey(id,name,profile_image)').or('sender_id.eq.$me,receiver_id.eq.$me').eq('status','accepted');
      final friends = <Map<String,dynamic>>[];
      for (final r in req) {
        final u = (r['sender_id'] == me ? r['receiver'] : r['sender']) as Map?;
        if (u != null) friends.add(Map<String,dynamic>.from(u));
      }
      if (mounted) setState(() { _friends = friends; _loading = false; });
    } catch (e) { if (mounted) { setState(() => _loading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل الدردشة: $e'))); } }
    if (widget.partnerId != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPartner(widget.partnerId!, widget.partnerName ?? 'Colleague'));
    }
  }

  Future<String?> _getConversation(String otherId) async {
    final me = uid;
    if (me == null) return null;
    final created = await db.rpc(
      'create_direct_conversation',
      params: {'other_user_id': otherId},
    );
    return created?.toString();
  }

  Future<void> _openPartner(String id, String name) async {
    try {
      final cid = await _getConversation(id);
      if (!mounted || cid == null || cid.isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversationId: cid,
            partnerId: id,
            partnerName: name,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح الدردشة: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح الدردشة: $e')),
        );
      }
    }
  }

  @override Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    return Directionality(textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr, child: Scaffold(
      backgroundColor: const Color(0xFFF5FAF9),
      appBar: AppBar(title: Text(ar ? '💬 الدردشة' : '💬 Chat'), centerTitle: true, actions: [IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnonymousScreen())), icon: const Icon(Icons.visibility_off_rounded)), IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _friends.isEmpty ? Center(child: Text(ar ? 'أضف زملاء مقبولين لبدء الدردشة.' : 'Accept colleague requests to start chatting.')) : ListView.builder(padding: const EdgeInsets.all(14), itemCount: _friends.length, itemBuilder: (_, i) { final f = _friends[i]; final name = f['name']?.toString() ?? 'User'; return Card(child: ListTile(leading: _avatar(f), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(ar ? 'زميل مقبول' : 'Accepted colleague'), onTap: () => _openPartner(f['id'].toString(), name))); }),
    ));
  }
  Widget _avatar(Map<String,dynamic> u) { final image=u['profile_image']?.toString(); return CircleAvatar(backgroundImage:image!=null&&image.isNotEmpty?NetworkImage(image):null, child:image==null||image.isEmpty?const Icon(Icons.person):null); }
}

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final String partnerId;
  final String partnerName;
  const ChatDetailScreen({super.key, required this.conversationId, required this.partnerId, required this.partnerName});
  @override State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  SupabaseClient get db => Supabase.instance.client;
  String? get uid => db.auth.currentUser?.id;
  List<Map<String,dynamic>> _messages=[];
  bool _loading=true;
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }
  void _subscribe() {
    _messagesChannel = db.channel('zameel-chat:${widget.conversationId}');
    _messagesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) {
            final row = Map<String, dynamic>.from(payload.newRecord);
            if (!mounted || row['sender_id'] == uid) return;
            setState(() => _messages.add(row));
            _scrollToEnd();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows=await db.from('messages').select('id,content,sender_id,created_at,media_url,media_type,is_read').eq('conversation_id',widget.conversationId).order('created_at');
      if(mounted)setState(()=>_messages=List<Map<String,dynamic>>.from(rows));
    }catch(e){ if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحميل الرسائل: $e'))); }
    finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<void> _send() async {
    final text=_controller.text.trim(); if(text.isEmpty||uid==null)return;
    _controller.clear();
    try{ final row=await db.from('messages').insert({'conversation_id':widget.conversationId,'sender_id':uid,'content':text,'media_url':null,'media_type':null,'is_read':false}).select('id,content,sender_id,created_at,media_url,media_type,is_read').single(); if(mounted){setState(()=>_messages.add(Map<String,dynamic>.from(row))); _scrollToEnd();} }
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر إرسال الرسالة: $e')));}
  }
  void _scrollToEnd(){WidgetsBinding.instance.addPostFrameCallback((_) {if(_scroll.hasClients)_scroll.animateTo(_scroll.position.maxScrollExtent,duration:const Duration(milliseconds:200),curve:Curves.easeOut);});}

  Future<void> _call({required bool video}) async {
    try {
      final partner = await db
          .from('users')
          .select('allow_calls')
          .eq('id', widget.partnerId)
          .maybeSingle();
      if (partner?['allow_calls'] == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('هذا الزميل لا يسمح بالمكالمات')),
          );
        }
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetScreen(
          participantName: widget.partnerName,
          roomId: widget.conversationId,
          startImmediately: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    return Directionality(
      textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.partnerName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: ar ? 'مكالمة صوتية' : 'Voice call',
              onPressed: () => _call(video: false),
              icon: const Icon(Icons.call_rounded),
            ),
            IconButton(
              tooltip: ar ? 'مكالمة فيديو' : 'Video call',
              onPressed: () => _call(video: true),
              icon: const Icon(Icons.videocam_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(14),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final mine = m['sender_id'] == uid;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? const Color(0xFF18D3C3)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              m['content']?.toString() ?? '',
                              style: TextStyle(
                                color: mine ? Colors.white : Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: ar ? 'اكتب رسالة...' : 'Type a message...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
