import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../../services_community_chat.dart';
import '../anonymous/anonymous_screen.dart';
import '../meet/meet_screen.dart';
import 'package:zameel/theme/app_theme.dart';

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
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (uid == null) return;
    try {
      final me = uid!;
      final profile = await ZameelCommunityChatService.currentProfile();
      final req = await db.from('friend_requests').select('id,sender_id,receiver_id,status,sender:users!friend_requests_sender_id_fkey(id,name,profile_image),receiver:users!friend_requests_receiver_id_fkey(id,name,profile_image)').or('sender_id.eq.$me,receiver_id.eq.$me').eq('status','accepted');
      final friends = <Map<String,dynamic>>[];
      for (final r in req) {
        final u = (r['sender_id'] == me ? r['receiver'] : r['sender']) as Map?;
        if (u != null) friends.add(Map<String,dynamic>.from(u));
      }
      if (mounted) setState(() { _friends = friends; _profile = profile; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل الدردشة: $e'))); }
    }
    if (widget.partnerId != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPartner(widget.partnerId!, widget.partnerName ?? 'Colleague'));
    }
  }

  Future<String?> _getConversation(String otherId) async {
    final me = uid;
    if (me == null) return null;
    final created = await db.rpc('create_direct_conversation', params: {'other_user_id': otherId});
    return created?.toString();
  }

  Future<void> _openPartner(String id, String name) async {
    try {
      final cid = await _getConversation(id);
      if (!mounted || cid == null || cid.isEmpty) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(conversationId: cid, partnerId: id, partnerName: name)));
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح الدردشة: ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح الدردشة: $e')));
    }
  }

  String _profileValue(String key) => _profile?[key]?.toString().trim() ?? '';

  Future<void> _openCommunity(CommunityScope scope, String title, String subtitle) async {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityChatDetailScreen(scope: scope, title: title, subtitle: subtitle)));
  }

  @override Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final university = _profileValue('university');
    final college = _profileValue('college');
    final department = _profileValue('department');
    final academicReady = university.isNotEmpty && college.isNotEmpty;
    final majorReady = academicReady && department.isNotEmpty;
    return Directionality(
      textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: Text(ar ? '💬 الدردشة' : '💬 Chat'), centerTitle: true, actions: [IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnonymousScreen())), icon: const Icon(Icons.visibility_off_rounded)), IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
        body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(ar ? 'مجتمعات Zameel' : 'Zameel communities', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(ar ? 'الدردشة العامة تجمع جميع طلاب Zameel من جميع الجامعات.' : 'The public chat connects Zameel students from all universities.', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            _communityCard(
              icon: Icons.public_rounded,
              title: ar ? '🌐 العامة' : '🌐 General',
              subtitle: ar ? 'جميع طلاب Zameel من جميع الجامعات' : 'All Zameel students from all universities',
              onTap: () => _openCommunity(const CommunityScope.global(), ar ? '🌐 الدردشة العامة' : '🌐 General chat', ar ? 'جميع الجامعات' : 'All universities'),
            ),
            const SizedBox(height: 10),
            _communityCard(
              icon: Icons.school_rounded,
              title: ar ? '🏫 كليتي' : '🏫 My college',
              subtitle: academicReady ? '$college • $university' : (ar ? 'أكمل الجامعة والكلية في ملفك الشخصي' : 'Complete your university and college in your profile'),
              enabled: academicReady,
              onTap: academicReady ? () => _openCommunity(CommunityScope.faculty(university: university, college: college), ar ? '🏫 كلية $college' : '🏫 $college', university) : null,
            ),
            const SizedBox(height: 10),
            _communityCard(
              icon: Icons.menu_book_rounded,
              title: ar ? '📚 تخصصي' : '📚 My major',
              subtitle: majorReady ? '$department • $college' : (ar ? 'أكمل الجامعة والكلية والتخصص في ملفك الشخصي' : 'Complete university, college, and major in your profile'),
              enabled: majorReady,
              onTap: majorReady ? () => _openCommunity(CommunityScope.major(university: university, college: college, department: department), ar ? '📚 $department' : '📚 $department', college) : null,
            ),
            const SizedBox(height: 24),
            Text(ar ? 'الدردشة الخاصة' : 'Private chat', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (_friends.isEmpty)
              Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(ar ? 'أضف زملاء مقبولين لبدء الدردشة الخاصة.' : 'Accept colleagues to start private chats.')))
            else
              ..._friends.map((f) { final name = f['name']?.toString() ?? 'User'; return Card(child: ListTile(leading: _avatar(f), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(ar ? 'دردشة خاصة' : 'Private chat'), onTap: () => _openPartner(f['id'].toString(), name))); }),
          ],
        ),
      ),
    );
  }

  Widget _communityCard({required IconData icon, required String title, required String subtitle, required VoidCallback? onTap, bool enabled = true}) {
    return Card(
      elevation: 0,
      color: enabled ? Colors.white : AppTheme.muted.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(backgroundColor: AppTheme.primaryLight, child: Icon(icon, color: AppTheme.primaryDark)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _avatar(Map<String,dynamic> u) { final image=u['profile_image']?.toString(); return CircleAvatar(backgroundImage:image!=null&&image.isNotEmpty?NetworkImage(image):null, child:image==null||image.isEmpty?const Icon(Icons.person):null); }
}

class CommunityChatDetailScreen extends StatefulWidget {
  final CommunityScope scope;
  final String title;
  final String subtitle;
  const CommunityChatDetailScreen({super.key, required this.scope, required this.title, required this.subtitle});
  @override State<CommunityChatDetailScreen> createState() => _CommunityChatDetailScreenState();
}

class _CommunityChatDetailScreenState extends State<CommunityChatDetailScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  @override void initState() { super.initState(); _load(); _subscribe(); }

  Future<void> _load() async {
    try {
      final rows = await ZameelCommunityChatService.listMessages(widget.scope);
      if (mounted) setState(() => _messages = rows);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل الرسائل: $e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _subscribe() {
    final db = Supabase.instance.client;
    _channel = db.channel('zameel-community:${widget.scope.key}');
    _channel!.onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'community_messages', callback: (payload) {
      final row = Map<String, dynamic>.from(payload.newRecord);
      if (row['scope'] != widget.scope.scope || row['university']?.toString() != widget.scope.university || row['college']?.toString() != widget.scope.college || row['department']?.toString() != widget.scope.department) return;
      if (!mounted || _messages.any((m) => m['id']?.toString() == row['id']?.toString())) return;
      setState(() => _messages.add(row));
      _scrollToEnd();
    }).subscribe();
  }

  @override void dispose() { _channel?.unsubscribe(); _controller.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final row = await ZameelCommunityChatService.sendMessage(scope: widget.scope, content: text);
      _controller.clear();
      if (mounted) { setState(() => _messages.add(row)); _scrollToEnd(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: $e')));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  void _scrollToEnd() { WidgetsBinding.instance.addPostFrameCallback((_) { if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut); }); }

  @override Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return Directionality(textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr, child: Scaffold(
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: Column(children: [
        Container(width: double.infinity, margin: const EdgeInsets.fromLTRB(12, 10, 12, 4), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(14)), child: Text(widget.subtitle, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _messages.isEmpty ? Center(child: Text(ar ? 'لا توجد رسائل بعد. كن أول من يبدأ الحديث.' : 'No messages yet. Start the conversation.')) : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(12), itemCount: _messages.length, itemBuilder: (_, i) {
          final m = _messages[i];
          final mine = m['user_id']?.toString() == uid;
          final user = m['users'];
          final name = user is Map ? user['name']?.toString() ?? 'زميل' : 'زميل';
          return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), constraints: const BoxConstraints(maxWidth: 340), decoration: BoxDecoration(color: mine ? AppTheme.primaryLight : Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [if (!mine) Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text(m['content']?.toString() ?? ''), const SizedBox(height: 3), Text(m['created_at']?.toString() ?? '', style: const TextStyle(fontSize: 9, color: Colors.black45))])));
        })),
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 10), child: Row(children: [Expanded(child: TextField(controller: _controller, minLines: 1, maxLines: 4, textInputAction: TextInputAction.newline, decoration: InputDecoration(hintText: ar ? 'اكتب رسالة...' : 'Write a message...', filled: true, fillColor: AppTheme.muted.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)))), const SizedBox(width: 8), IconButton.filled(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded))]))),
      ]),
    ));
  }
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
                                  ? AppTheme.primary
                                  : AppTheme.muted.shade200,
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
