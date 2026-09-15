import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../providers/language_provider.dart';
import '../../services_community_chat.dart';
import '../anonymous/anonymous_screen.dart';
import '../meet/meet_screen.dart';
import 'package:zameel/theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String? partnerId;
  final String? partnerName;
  const ChatScreen({super.key, this.partnerId, this.partnerName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  SupabaseClient get db => Supabase.instance.client;
  String? get uid => db.auth.currentUser?.id;
  List<Map<String, dynamic>> _friends = [];
  Map<String, dynamic>? _profile;
  bool _loading = true;
  Set<String> _onlineIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (uid == null) return;
    try {
      final me = uid!;
      final profile = await ZameelCommunityChatService.currentProfile();
      await db.rpc('touch_my_presence');
      List<dynamic> presence = const [];
      try {
        final presenceRows = await db.rpc('get_colleague_presence');
        presence = List<dynamic>.from(presenceRows as List? ?? const []);
      } catch (_) {}
      final req = await db
          .from('friend_requests')
          .select(
              'id,sender_id,receiver_id,status,sender:users!friend_requests_sender_id_fkey(id,name,profile_image),receiver:users!friend_requests_receiver_id_fkey(id,name,profile_image)')
          .or('sender_id.eq.$me,receiver_id.eq.$me')
          .eq('status', 'accepted');
      final friends = <Map<String, dynamic>>[];
      for (final r in req) {
        final u = (r['sender_id'] == me ? r['receiver'] : r['sender']) as Map?;
        if (u != null) friends.add(Map<String, dynamic>.from(u));
      }
      if (mounted)
        setState(() {
          _friends = friends;
          _profile = profile;
          _onlineIds = presence
              .where((p) => p is Map && p['is_online'] == true)
              .map((p) => (p as Map)['user_id'].toString())
              .toSet();
          _loading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر تحميل الدردشة: $e')));
      }
    }
    if (widget.partnerId != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _openPartner(widget.partnerId!, widget.partnerName ?? 'Colleague'));
    }
  }

  Future<String?> _getConversation(String otherId) async {
    final me = uid;
    if (me == null) return null;
    final created = await db
        .rpc('create_direct_conversation', params: {'other_user_id': otherId});
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
                  conversationId: cid, partnerId: id, partnerName: name)));
    } on PostgrestException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر فتح الدردشة: ${e.message}')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر فتح الدردشة: $e')));
    }
  }

  String _profileValue(String key) => _profile?[key]?.toString().trim() ?? '';

  Future<void> _openCommunity(
      CommunityScope scope, String title, String subtitle) async {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CommunityChatDetailScreen(
                scope: scope, title: title, subtitle: subtitle)));
  }

  @override
  Widget build(BuildContext context) {
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
        appBar: AppBar(
            title: Text(ar ? '💬 الدردشة' : '💬 Chat'),
            centerTitle: true,
            actions: [
              IconButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AnonymousScreen())),
                  icon: const Icon(Icons.visibility_off_rounded)),
              IconButton(
                  onPressed: _load, icon: const Icon(Icons.refresh_rounded))
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Text(ar ? 'مجتمعات Zameel' : 'Zameel communities',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                      ar
                          ? 'الدردشة العامة تجمع جميع طلاب Zameel من جميع الجامعات.'
                          : 'The public chat connects Zameel students from all universities.',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  _communityCard(
                    icon: Icons.public_rounded,
                    title: ar ? '🌐 العامة' : '🌐 General',
                    subtitle: ar
                        ? 'جميع طلاب Zameel من جميع الجامعات'
                        : 'All Zameel students from all universities',
                    onTap: () => _openCommunity(
                        const CommunityScope.global(),
                        ar ? '🌐 الدردشة العامة' : '🌐 General chat',
                        ar ? 'جميع الجامعات' : 'All universities'),
                  ),
                  const SizedBox(height: 10),
                  _communityCard(
                    icon: Icons.school_rounded,
                    title: ar ? '🏫 كليتي' : '🏫 My college',
                    subtitle: academicReady
                        ? '$college • $university'
                        : (ar
                            ? 'أكمل الجامعة والكلية في ملفك الشخصي'
                            : 'Complete your university and college in your profile'),
                    enabled: academicReady,
                    onTap: academicReady
                        ? () => _openCommunity(
                            CommunityScope.faculty(
                                university: university, college: college),
                            ar ? '🏫 كلية $college' : '🏫 $college',
                            university)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _communityCard(
                    icon: Icons.menu_book_rounded,
                    title: ar ? '📚 تخصصي' : '📚 My major',
                    subtitle: majorReady
                        ? '$department • $college'
                        : (ar
                            ? 'أكمل الجامعة والكلية والتخصص في ملفك الشخصي'
                            : 'Complete university, college, and major in your profile'),
                    enabled: majorReady,
                    onTap: majorReady
                        ? () => _openCommunity(
                            CommunityScope.major(
                                university: university,
                                college: college,
                                department: department),
                            ar ? '📚 $department' : '📚 $department',
                            college)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(ar ? 'الدردشة الخاصة' : 'Private chat',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (_friends.isEmpty)
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                            child: Text(ar
                                ? 'أضف زملاء مقبولين لبدء الدردشة الخاصة.'
                                : 'Accept colleagues to start private chats.')))
                  else
                    ..._friends.map((f) {
                      final name = f['name']?.toString() ?? 'User';
                      final online = _onlineIds.contains(f['id']?.toString());
                      return Card(
                          child: ListTile(
                              leading:
                                  Stack(clipBehavior: Clip.none, children: [
                                _avatar(f),
                                if (online)
                                  const Positioned(
                                      right: -1,
                                      bottom: -1,
                                      child: CircleAvatar(
                                          radius: 7,
                                          backgroundColor: Colors.white,
                                          child: CircleAvatar(
                                              radius: 5,
                                              backgroundColor: Colors.green)))
                              ]),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: Text(
                                  online
                                      ? (ar ? 'متصل الآن' : 'Online now')
                                      : (ar ? 'دردشة خاصة' : 'Private chat'),
                                  style: TextStyle(
                                      color: online ? Colors.green : null)),
                              onTap: () =>
                                  _openPartner(f['id'].toString(), name)));
                    }),
                ],
              ),
      ),
    );
  }

  Widget _communityCard(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback? onTap,
      bool enabled = true}) {
    return Card(
      elevation: 0,
      color: enabled ? Colors.white : AppTheme.muted.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
            backgroundColor: AppTheme.primaryLight,
            child: Icon(icon, color: AppTheme.primaryDark)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> u) {
    final image = u['profile_image']?.toString();
    return CircleAvatar(
        backgroundImage:
            image != null && image.isNotEmpty ? NetworkImage(image) : null,
        child:
            image == null || image.isEmpty ? const Icon(Icons.person) : null);
  }
}

class CommunityChatDetailScreen extends StatefulWidget {
  final CommunityScope scope;
  final String title;
  final String subtitle;
  const CommunityChatDetailScreen(
      {super.key,
      required this.scope,
      required this.title,
      required this.subtitle});
  @override
  State<CommunityChatDetailScreen> createState() =>
      _CommunityChatDetailScreenState();
}

class _CommunityChatDetailScreenState extends State<CommunityChatDetailScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  Future<void> _load() async {
    try {
      final rows = await ZameelCommunityChatService.listMessages(widget.scope);
      if (mounted) setState(() => _messages = rows);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر تحميل الرسائل: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    final db = Supabase.instance.client;
    _channel = db.channel('zameel-community:${widget.scope.key}');
    _channel!
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'community_messages',
            callback: (payload) {
              final row = Map<String, dynamic>.from(payload.newRecord);
              if (row['scope'] != widget.scope.scope ||
                  row['university']?.toString() != widget.scope.university ||
                  row['college']?.toString() != widget.scope.college ||
                  row['department']?.toString() != widget.scope.department)
                return;
              if (!mounted ||
                  _messages
                      .any((m) => m['id']?.toString() == row['id']?.toString()))
                return;
              setState(() => _messages.add(row));
              _scrollToEnd();
            })
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final row = await ZameelCommunityChatService.sendMessage(
          scope: widget.scope, content: text);
      _controller.clear();
      if (mounted) {
        setState(() => _messages.add(row));
        _scrollToEnd();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return Directionality(
        textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
              title: Text(widget.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true),
          body: Column(children: [
            Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(14)),
                child: Text(widget.subtitle,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? Center(
                            child: Text(ar
                                ? 'لا توجد رسائل بعد. كن أول من يبدأ الحديث.'
                                : 'No messages yet. Start the conversation.'))
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final m = _messages[i];
                              final mine = m['user_id']?.toString() == uid;
                              final user = m['users'];
                              final name = user is Map
                                  ? user['name']?.toString() ?? 'زميل'
                                  : 'زميل';
                              return Align(
                                  alignment: mine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      constraints:
                                          const BoxConstraints(maxWidth: 340),
                                      decoration: BoxDecoration(
                                          color: mine
                                              ? AppTheme.primaryLight
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      child: Column(
                                          crossAxisAlignment: mine
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            if (!mine)
                                              Text(name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12)),
                                            Text(
                                                m['content']?.toString() ?? ''),
                                            const SizedBox(height: 3),
                                            Text(
                                                m['created_at']?.toString() ??
                                                    '',
                                                style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.black45))
                                          ])));
                            })),
            SafeArea(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                    child: Row(children: [
                      Expanded(
                          child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                  hintText: ar
                                      ? 'اكتب رسالة...'
                                      : 'Write a message...',
                                  filled: true,
                                  fillColor: AppTheme.muted.shade100,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none)))),
                      const SizedBox(width: 8),
                      IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send_rounded))
                    ]))),
          ]),
        ));
  }
}

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final String partnerId;
  final String partnerName;
  final bool allowCalls;
  final String? contextLabel;
  final String? bookRequestId;
  final String? contextPhone;
  const ChatDetailScreen(
      {super.key,
      required this.conversationId,
      required this.partnerId,
      required this.partnerName,
      this.allowCalls = true,
      this.contextLabel,
      this.bookRequestId,
      this.contextPhone});
  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  SupabaseClient get db => Supabase.instance.client;
  String? get uid => db.auth.currentUser?.id;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _meetChannel;
  Timer? _meetTimer;
  Timer? _presenceTimer;
  Map<String, dynamic>? _activeMeet;
  bool _uploading = false;
  final Map<String, String> _signedAttachments = {};

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
    _subscribeMeet();
    _refreshMeet();
    _meetTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _refreshMeet(silent: true));
    db.rpc('touch_my_presence');
    _presenceTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => db.rpc('touch_my_presence'));
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
            if (_messages.any((m) => m['id']?.toString() == row['id']?.toString())) return;
            setState(() => _messages.add(row));
            _markRead();
            _scrollToEnd();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) {
            final row = Map<String, dynamic>.from(payload.newRecord);
            final index = _messages.indexWhere(
                (m) => m['id']?.toString() == row['id']?.toString());
            if (mounted && index >= 0) setState(() => _messages[index] = row);
          },
        )
        .subscribe();
  }

  void _subscribeMeet() {
    _meetChannel = db.channel('zameel-meet-status:${widget.conversationId}');
    _meetChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'meet_colleague_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (_) => _refreshMeet(silent: true),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _meetChannel?.unsubscribe();
    _meetTimer?.cancel();
    _presenceTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await db
          .from('messages')
          .select(
              'id,content,sender_id,created_at,media_url,media_type,is_read,delivered_at,read_at')
          .eq('conversation_id', widget.conversationId)
          .order('created_at');
      if (mounted)
        setState(() => _messages = List<Map<String, dynamic>>.from(rows));
      await _markRead();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر تحميل الرسائل: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || uid == null) return;
    try {
      final result = await db.rpc('send_direct_message', params: {
        'target_conversation_id': widget.conversationId,
        'message_content': text,
      });
      final rows = List<Map<String, dynamic>>.from(result as List? ?? const []);
      if (rows.isEmpty) throw StateError('message_not_saved');
      final row = rows.first;
      if (mounted) {
        _controller.clear();
        if (!_messages.any((m) => m['id']?.toString() == row['id']?.toString())) {
          setState(() => _messages.add(Map<String, dynamic>.from(row)));
        }
        _scrollToEnd();
      }
      // Reconcile with the database so a local bubble is never mistaken for
      // a message that was not persisted.
      unawaited(Future<void>.delayed(const Duration(milliseconds: 500), _load));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: $e')));
    }
  }

  Future<void> _pickAttachment() async {
    if (_uploading || uid == null) return;
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      _notice('تعذر قراءة الملف المختار');
      return;
    }
    if (bytes.length > 15 * 1024 * 1024) {
      _notice('الحد الأقصى للمرفق 15 ميجابايت');
      return;
    }
    setState(() => _uploading = true);
    try {
      final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '${uid!}/${widget.conversationId}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
      final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
      final image = const {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(extension);
      final imageMime = extension == 'jpg' ? 'jpeg' : extension;
      await db.storage.from('chat_attachments').uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(contentType: image ? 'image/$imageMime' : 'application/octet-stream'),
      );
      final row = await db.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': uid,
        'content': file.name,
        'media_url': path,
        'media_type': image ? 'image' : 'file',
        'is_read': false,
      }).select('id,content,sender_id,created_at,media_url,media_type,is_read,delivered_at,read_at').single();
      await db.from('chat_attachments').insert({
        'conversation_id': widget.conversationId,
        'message_id': row['id'],
        'uploader_id': uid,
        'object_path': path,
        'file_name': file.name,
        'file_size': bytes.length,
        'media_type': image ? 'image' : 'file',
      });
      if (mounted) {
        setState(() => _messages.add(Map<String, dynamic>.from(row)));
        _scrollToEnd();
      }
    } catch (e) {
      _notice('تعذر إرسال المرفق: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _notice(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _attachmentUrl(String path) async {
    final cached = _signedAttachments[path];
    if (cached != null) return cached;
    try {
      final url = await db.storage.from('chat_attachments').createSignedUrl(path, 3600);
      _signedAttachments[path] = url;
      return url;
    } catch (_) {
      return null;
    }
  }

  Widget _messageContent(Map<String, dynamic> message, bool mine) {
    final path = message['media_url']?.toString() ?? '';
    final type = message['media_type']?.toString() ?? '';
    if (path.isEmpty) {
      return Text(message['content']?.toString() ?? '', style: TextStyle(color: mine ? Colors.white : Colors.black87, fontSize: 15));
    }
    return FutureBuilder<String?>(
      future: _attachmentUrl(path),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) return const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2));
        if (type == 'image') {
          return GestureDetector(
            onTap: () => showDialog<void>(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(url)))),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, width: 220, height: 180, fit: BoxFit.cover)),
          );
        }
        return InkWell(
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.insert_drive_file_rounded, color: mine ? Colors.white : AppTheme.primary),
            const SizedBox(width: 8),
            Flexible(child: Text(message['content']?.toString() ?? 'ملف', style: TextStyle(color: mine ? Colors.white : Colors.black87))),
          ]),
        );
      },
    );
  }

  Future<void> _markRead() async {
    try {
      await db.rpc('mark_conversation_read', params: {
        'target_conversation_id': widget.conversationId,
      });
    } catch (_) {}
  }

  Future<Position?> _position(bool ar) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ar
                ? 'فعّل خدمة الموقع أولاً'
                : 'Enable location services first')));
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ar
                ? 'يلزم السماح بالموقع لاستخدام «التقِ بزميل»'
                : 'Location permission is required')));
      return null;
    }
    return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _refreshMeet({bool silent = false}) async {
    try {
      final rows = await db.rpc('get_active_meet_colleague',
          params: {'target_conversation_id': widget.conversationId});
      final next = rows is List && rows.isNotEmpty
          ? Map<String, dynamic>.from(rows.first as Map)
          : null;
      if (mounted) setState(() => _activeMeet = next);
    } catch (e) {
      if (!silent && mounted) debugPrint('Meet status: $e');
    }
  }

  Future<void> _meetAction(bool ar) async {
    final meet = _activeMeet;
    if (meet == null) {
      final agreed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: Text(ar ? 'التقِ بزميل' : 'Meet a colleague'),
                content: Text(ar
                    ? 'سيُرسل طلب موافقة لزميلك. لن يظهر موقع أي طرف إلا داخل هذه المحادثة ولمدة ساعتين.'
                    : 'Your colleague must consent. Locations are visible only in this chat for two hours.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(ar ? 'إلغاء' : 'Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(ar ? 'إرسال الطلب' : 'Send request'))
                ],
              ));
      if (agreed != true) return;
      final p = await _position(ar);
      if (p == null) return;
      await db.rpc('request_meet_colleague', params: {
        'target_conversation_id': widget.conversationId,
        'target_recipient_id': widget.partnerId,
        'my_lat': p.latitude,
        'my_lng': p.longitude
      });
      await _refreshMeet();
      return;
    }
    if (meet['status'] == 'accepted') {
      if (mounted) setState(() {});
      return;
    }
    if (meet['recipient_id']?.toString() == uid) {
      final accept = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: Text(ar
                    ? 'طلب لقاء من ${widget.partnerName}'
                    : 'Meet request from ${widget.partnerName}'),
                content: Text(ar
                    ? 'هل توافق على مشاركة موقعك مؤقتًا وفتح خريطة الالتقاء؟'
                    : 'Share your location temporarily and open the meeting map?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(ar ? 'رفض' : 'Decline')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(ar ? 'موافقة' : 'Accept'))
                ],
              ));
      if (accept == null) return;
      Position? p;
      if (accept) p = await _position(ar);
      if (accept && p == null) return;
      await db.rpc('respond_meet_colleague', params: {
        'target_request_id': meet['request_id'],
        'accept_request': accept,
        'my_lat': p?.latitude,
        'my_lng': p?.longitude
      });
      await _refreshMeet();
      if (accept && mounted) setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar
              ? 'بانتظار موافقة ${widget.partnerName}'
              : 'Waiting for ${widget.partnerName}')));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _call({required bool video}) async {
    final me = uid;
    if (me == null) return;
    final roomId =
        'call:${widget.conversationId}:${DateTime.now().microsecondsSinceEpoch}';

    try {
      await db.rpc(
        'start_direct_call',
        params: {
          'other_user_id': widget.partnerId,
          'target_conversation_id': widget.conversationId,
          'target_room_id': roomId,
          'with_video': video,
        },
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final message = e.message.contains('calls_disabled')
          ? 'هذا الزميل لا يسمح بالمكالمات'
          : 'تعذر بدء المكالمة: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر بدء المكالمة: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetScreen(
          participantName: widget.partnerName,
          roomId: roomId,
          startImmediately: true,
          startWithVideo: video,
          isInitiator: true,
        ),
      ),
    );
  }

  Future<void> _showCallHistory(bool ar) async {
    try {
      final raw = await db.rpc(
        'get_call_history',
        params: {'target_conversation_id': widget.conversationId},
      );
      final rows = List<Map<String, dynamic>>.from(raw as List);
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .7,
          builder: (_, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  ar ? 'سجل المكالمات' : 'Call history',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          ar ? 'لا توجد مكالمات' : 'No calls',
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: rows.length,
                        itemBuilder: (_, index) {
                          final call = rows[index];
                          final duration =
                              (call['duration_seconds'] as num?)?.toInt() ?? 0;
                          final createdAt = DateTime.tryParse(
                            call['created_at']?.toString() ?? '',
                          )?.toLocal();
                          final incoming = call['direction'] == 'incoming';
                          final direction = incoming
                              ? (ar ? 'واردة' : 'Incoming')
                              : (ar ? 'صادرة' : 'Outgoing');
                          final status = call['status']?.toString() ?? '';
                          final durationText =
                              '${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}';
                          final dateText = createdAt == null
                              ? ''
                              : DateFormat('yyyy/MM/dd HH:mm')
                                  .format(createdAt);

                          return ListTile(
                            leading: Icon(
                              call['with_video'] == true
                                  ? Icons.videocam_rounded
                                  : Icons.call_rounded,
                            ),
                            title: Text('$direction • $status'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateText.isEmpty
                                      ? durationText
                                      : '$durationText • $dateText',
                                ),
                                Wrap(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(sheetContext);
                                        _call(video: false);
                                      },
                                      child: Text(
                                        ar
                                            ? 'إعادة الاتصال: صوتي'
                                            : 'Call again: voice',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(sheetContext);
                                        _call(video: true);
                                      },
                                      child: Text(
                                        ar ? 'فيديو' : 'Video',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ar ? 'تعذر تحميل السجل' : 'Could not load history'}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _completeBookHandover(bool ar) async {
    final requestId = widget.bookRequestId;
    if (requestId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ar ? 'إتمام عملية الكتاب؟' : 'Complete book handover?'),
        content: Text(ar ? 'سيتم تسجيل التسليم وإزالة الكتاب من العروض المتاحة، مع بقاء سجل المحادثة.' : 'The handover will be recorded and the listing removed while the conversation remains available.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(ar ? 'تم التسليم' : 'Handed over')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await db.rpc('complete_book_exchange', params: {'target_request_id': requestId});
      _notice(ar ? 'تم تسجيل تسليم الكتاب' : 'Book handover recorded');
    } catch (e) {
      _notice('${ar ? 'تعذر إتمام العملية' : 'Could not complete handover'}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    return Directionality(
      textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.partnerName, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (widget.contextLabel != null) Text(widget.contextLabel!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
          ]),
          actions: [
            if (widget.bookRequestId != null) IconButton(
              tooltip: ar ? 'تم التسليم' : 'Handed over',
              onPressed: () => _completeBookHandover(ar),
              icon: const Icon(Icons.task_alt_rounded),
            ),
            if (widget.allowCalls) IconButton(
                tooltip: ar ? 'سجل المكالمات' : 'Call history',
                onPressed: () => _showCallHistory(ar),
                icon: const Icon(Icons.history_rounded)),
            IconButton(
              tooltip: ar ? 'التقِ بزميل' : 'Meet a colleague',
              onPressed: () => _meetAction(ar),
              icon: Badge(
                isLabelVisible: _activeMeet?['status'] == 'pending' &&
                    _activeMeet?['recipient_id']?.toString() == uid,
                child: Icon(_activeMeet?['status'] == 'accepted'
                    ? Icons.map_rounded
                    : Icons.person_pin_circle_rounded),
              ),
            ),
            if (widget.allowCalls) IconButton(
              tooltip: ar ? 'مكالمة صوتية' : 'Voice call',
              onPressed: () => _call(video: false),
              icon: const Icon(Icons.call_rounded),
            ),
            if (widget.allowCalls) IconButton(
              tooltip: ar ? 'مكالمة فيديو' : 'Video call',
              onPressed: () => _call(video: true),
              icon: const Icon(Icons.videocam_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            if (widget.contextPhone?.isNotEmpty == true)
              ListTile(
                dense: true,
                leading: const Icon(Icons.phone_rounded, color: AppTheme.primary),
                title: Text(ar ? 'رقم التواصل المضاف للكتاب' : 'Book contact number'),
                subtitle: SelectableText(widget.contextPhone!),
              ),
            Expanded(
              child: Column(
                children: [
                  if (_activeMeet?['status'] == 'pending')
                    _meetRequestBanner(ar),
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        _messageContent(m, mine),
                                        if (mine) ...[
                                          const SizedBox(height: 3),
                                          Icon(
                                            m['read_at'] != null
                                                ? Icons.done_all_rounded
                                                : m['delivered_at'] != null
                                                    ? Icons.done_all_rounded
                                                    : Icons.done_rounded,
                                            size: 15,
                                            color: m['read_at'] != null
                                                ? Colors.cyanAccent
                                                : Colors.white70,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )),
                  if (_activeMeet?['status'] == 'accepted')
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .48,
                      child: MeetColleaguePanel(
                        meet: _activeMeet!,
                        partnerName: widget.partnerName,
                        onEnded: () => setState(() => _activeMeet = null),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: ar ? 'إرفاق صورة أو ملف' : 'Attach image or file',
                    onPressed: _uploading ? null : _pickAttachment,
                    icon: _uploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.attach_file_rounded),
                  ),
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

  Widget _meetRequestBanner(bool ar) {
    final mine = _activeMeet?['requester_id']?.toString() == uid;
    return Material(
      color: AppTheme.primaryLight,
      child: ListTile(
        leading: const Icon(Icons.person_pin_circle_rounded),
        title: Text(mine
            ? (ar
                ? 'بانتظار موافقة ${widget.partnerName}'
                : 'Waiting for approval')
            : (ar ? 'طلب لقاء من ${widget.partnerName}' : 'Meeting request')),
        trailing: mine
            ? null
            : FilledButton(
                onPressed: () => _meetAction(ar),
                child: Text(ar ? 'عرض' : 'View')),
      ),
    );
  }
}

class MeetColleaguePanel extends StatefulWidget {
  final Map<String, dynamic> meet;
  final String partnerName;
  final VoidCallback onEnded;
  const MeetColleaguePanel(
      {super.key,
      required this.meet,
      required this.partnerName,
      required this.onEnded});

  @override
  State<MeetColleaguePanel> createState() => _MeetColleaguePanelState();
}

class _MeetColleaguePanelState extends State<MeetColleaguePanel> {
  late Map<String, dynamic> _meet;
  Timer? _timer;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _meet = Map<String, dynamic>.from(widget.meet);
    _sync();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _sync());
  }

  Future<void> _sync() async {
    if (_updating) return;
    _updating = true;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high, distanceFilter: 3));
        await Supabase.instance.client.rpc('update_my_meet_location', params: {
          'target_request_id': _meet['request_id'],
          'my_lat': p.latitude,
          'my_lng': p.longitude
        });
      }
      final row = await Supabase.instance.client
          .from('meet_colleague_requests')
          .select()
          .eq('id', _meet['request_id'])
          .maybeSingle();
      if (row == null || row['status'] != 'accepted') {
        widget.onEnded();
        return;
      }
      if (mounted) setState(() => _meet = Map<String, dynamic>.from(row));
    } catch (_) {
    } finally {
      _updating = false;
    }
  }

  Future<void> _end(bool complete) async {
    await Supabase.instance.client.rpc('end_meet_colleague', params: {
      'target_request_id': _meet['request_id'],
      'complete_meet': complete
    });
    widget.onEnded();
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final a = LatLng((_meet['requester_lat'] as num).toDouble(),
        (_meet['requester_lng'] as num).toDouble());
    final b = LatLng((_meet['recipient_lat'] as num).toDouble(),
        (_meet['recipient_lng'] as num).toDouble());
    final meters = const Distance().as(LengthUnit.Meter, a, b);
    final midpoint =
        LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
    final walkMinutes = math.max(1, (meters / 80).ceil());
    final driveMinutes = math.max(1, (meters / 420).ceil());
    final distanceText = meters < 1000
        ? '${meters.round()} ${ar ? 'متر' : 'm'}'
        : '${(meters / 1000).toStringAsFixed(1)} ${ar ? 'كم' : 'km'}';
    return DecoratedBox(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.primary, width: 2))),
      child: Stack(children: [
        FlutterMap(
            options: MapOptions(initialCenter: midpoint, initialZoom: 15),
            children: [
              TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zameel.app'),
              PolylineLayer(polylines: [
                Polyline(
                    points: [a, b], strokeWidth: 5, color: AppTheme.primary)
              ]),
              MarkerLayer(markers: [
                Marker(
                    point: a,
                    width: 55,
                    height: 55,
                    child: const Icon(Icons.person_pin_circle_rounded,
                        size: 48, color: AppTheme.primaryDark)),
                Marker(
                    point: b,
                    width: 55,
                    height: 55,
                    child: const Icon(Icons.location_on_rounded,
                        size: 48, color: Colors.orange)),
              ]),
              RichAttributionWidget(attributions: const [
                TextSourceAttribution('OpenStreetMap contributors')
              ]),
            ]),
        Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Card(
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(children: [
                      Expanded(
                          child: Text(
                              '$distanceText • ${ar ? 'مشي' : 'Walk'} $walkMinutes ${ar ? 'د' : 'm'} • ${ar ? 'سيارة' : 'Drive'} $driveMinutes ${ar ? 'د' : 'm'}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800))),
                      IconButton(
                          tooltip: ar ? 'إنهاء اللقاء' : 'End meeting',
                          onPressed: () => _end(false),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.red)),
                      IconButton(
                          tooltip: ar ? 'وصلت' : 'Arrived',
                          onPressed: () => _end(true),
                          icon: const Icon(Icons.flag_rounded,
                              color: Colors.green)),
                    ])))),
      ]),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class MeetColleagueMapScreen extends StatelessWidget {
  final Map<String, dynamic> meet;
  final String partnerName;
  const MeetColleagueMapScreen(
      {super.key, required this.meet, required this.partnerName});

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final a = LatLng((meet['requester_lat'] as num).toDouble(),
        (meet['requester_lng'] as num).toDouble());
    final b = LatLng((meet['recipient_lat'] as num).toDouble(),
        (meet['recipient_lng'] as num).toDouble());
    final meters = const Distance().as(LengthUnit.Meter, a, b);
    final midpoint =
        LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
    return Directionality(
        textDirection: ar ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
              title: Text(ar ? 'خريطة الالتقاء' : 'Meeting map'),
              actions: [
                IconButton(
                    tooltip: ar ? 'إيقاف مشاركة الموقع' : 'Stop sharing',
                    icon: const Icon(Icons.location_off_rounded),
                    onPressed: () async {
                      await Supabase.instance.client.rpc(
                          'cancel_meet_colleague',
                          params: {'target_request_id': meet['request_id']});
                      if (context.mounted) Navigator.pop(context);
                    }),
              ]),
          body: Column(children: [
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: AppTheme.primaryLight,
                child: Text(
                    ar
                        ? 'المسافة التقريبية بينكما: ${meters.round()} متر\nالتقيا في مكان عام وآمن، واتفقا عبر الدردشة على نقطة واضحة.'
                        : 'Approximate distance: ${meters.round()} m\nMeet in a safe public place and agree on a clear landmark in chat.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            Expanded(
                child: FlutterMap(
                    options:
                        MapOptions(initialCenter: midpoint, initialZoom: 16),
                    children: [
                  TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.zameel.app'),
                  PolylineLayer(polylines: [
                    Polyline(
                        points: [a, b], strokeWidth: 5, color: AppTheme.primary)
                  ]),
                  MarkerLayer(markers: [
                    Marker(
                        point: a,
                        width: 70,
                        height: 70,
                        child: const Icon(Icons.person_pin_circle_rounded,
                            size: 48, color: AppTheme.primaryDark)),
                    Marker(
                        point: b,
                        width: 70,
                        height: 70,
                        child: const Icon(Icons.location_on_rounded,
                            size: 48, color: Colors.orange)),
                  ]),
                ])),
            SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: FilledButton.icon(
                      onPressed: () => launchUrl(
                          Uri.parse(
                              'https://www.google.com/maps/dir/?api=1&origin=${a.latitude},${a.longitude}&destination=${b.latitude},${b.longitude}&travelmode=walking'),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.directions_walk_rounded),
                      label: Text(
                          ar ? 'طريقة الالتقاء والمشي' : 'Walking directions'),
                    ))),
          ]),
        ));
  }
}
