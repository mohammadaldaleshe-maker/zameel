import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/chat_timestamp.dart';
import '../../widgets/chat_voice_widgets.dart';
import '../../widgets/keep_keyboard_send_button.dart';
import '../../widgets/linkified_text165.dart';
import '../../widgets/video_player_widget.dart';

class LammaChatScreen extends StatefulWidget {
  final String lammaId;
  final String title;

  const LammaChatScreen(
      {super.key, required this.lammaId, required this.title});

  @override
  State<LammaChatScreen> createState() => _LammaChatScreenState();
}

class _LammaChatScreenState extends State<LammaChatScreen> {
  static const int _maxMediaBytes = 25 * 1024 * 1024;
  static const String _bucket = 'lamma_media';

  final _message = TextEditingController();
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();
  final _db = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _stream;
  bool _sending = false;
  bool _uploading = false;
  bool? _isMember;
  bool _stickToEnd = true;
  int _lastCount = 0;
  String? _creatorId;
  List<Map<String, dynamic>> _members = <Map<String, dynamic>>[];
  Map<String, String> _names = <String, String>{};

  @override
  void initState() {
    super.initState();
    _stream = _db
        .from('social_lamma_messages')
        .stream(primaryKey: ['id'])
        .eq('lamma_id', widget.lammaId)
        .order('created_at');
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      _stickToEnd =
          _scroll.position.maxScrollExtent - _scroll.position.pixels < 120;
    });
    _loadMembers();
  }

  @override
  void dispose() {
    _message.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  /// The server only returns the member list to members. A refusal therefore
  /// also tells us that the user was removed (or left) and may not chat.
  Future<void> _loadMembers() async {
    try {
      final rows = await _db
          .rpc('get_lamma_members', params: {'p_lamma': widget.lammaId});
      final list = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final names = <String, String>{};
      String? creator;
      for (final row in list) {
        final id = row['user_id']?.toString() ?? '';
        final name = row['name']?.toString().trim() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) names[id] = name;
        if (row['is_creator'] == true) creator = id;
      }
      if (!mounted) return;
      setState(() {
        _members = list;
        _names = names;
        _creatorId = creator;
        _isMember = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('membership_required')) {
        setState(() => _isMember = false);
      }
    }
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    final user = _db.auth.currentUser;
    if (body.isEmpty || user == null || _sending || _isMember == false) return;
    setState(() => _sending = true);
    try {
      await _db.from('social_lamma_messages').insert({
        'lamma_id': widget.lammaId,
        'sender_id': user.id,
        'body': body,
      });
      _message.clear();
      _stickToEnd = true;
    } catch (_) {
      _notice('تعذر إرسال الرسالة. تأكد أنك عضو في اللّمّة.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _extensionOf(String name, String fallback) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return fallback;
    final ext = name.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext) ? ext : fallback;
  }

  static String? _mimeFor(String type, String extension) {
    switch (type) {
      case 'image':
        const images = {
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'webp': 'image/webp',
          'gif': 'image/gif',
        };
        return images[extension];
      case 'video':
        const videos = {
          'mp4': 'video/mp4',
          'mov': 'video/quicktime',
          'webm': 'video/webm',
        };
        return videos[extension];
      case 'audio':
        return extension == 'm4a' ? 'audio/mp4' : null;
    }
    return null;
  }

  static String _labelFor(String type) {
    switch (type) {
      case 'image':
        return 'صورة';
      case 'video':
        return 'فيديو';
      default:
        return 'رسالة صوتية';
    }
  }

  Future<void> _sendMedia({
    required Uint8List bytes,
    required String extension,
    required String type,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null || _uploading || _isMember == false) return;
    if (bytes.isEmpty || bytes.length > _maxMediaBytes) {
      _notice('حجم الملف كبير. الحد الأقصى 25 ميغابايت.');
      return;
    }
    final mime = _mimeFor(type, extension);
    if (mime == null) {
      _notice('صيغة الملف غير مدعومة.');
      return;
    }
    setState(() => _uploading = true);
    String? uploadedPath;
    try {
      final path =
          '${user.id}/${widget.lammaId}/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await _db.storage.from(_bucket).uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: mime));
      uploadedPath = path;
      await _db.from('social_lamma_messages').insert({
        'lamma_id': widget.lammaId,
        'sender_id': user.id,
        'body': _labelFor(type),
        'media_url': path,
        'media_type': type,
      });
      _stickToEnd = true;
    } catch (_) {
      final orphan = uploadedPath;
      if (orphan != null) {
        try {
          await _db.storage.from(_bucket).remove(<String>[orphan]);
        } catch (_) {}
      }
      _notice('تعذر إرسال المرفق. تحقق من الاتصال وأنك عضو في اللّمّة.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 85, maxWidth: 1920);
      if (picked == null) return;
      await _sendMedia(
          bytes: await picked.readAsBytes(),
          extension: _extensionOf(picked.name, 'jpg'),
          type: 'image');
    } catch (_) {
      _notice('تعذر فتح الاستديو. تحقق من صلاحيات الصور والفيديو');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await ImagePicker().pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 3));
      if (picked == null) return;
      if (await picked.length() > _maxMediaBytes) {
        _notice('حجم الفيديو كبير. الحد الأقصى 25 ميغابايت.');
        return;
      }
      await _sendMedia(
          bytes: await picked.readAsBytes(),
          extension: _extensionOf(picked.name, 'mp4'),
          type: 'video');
    } catch (_) {
      _notice('تعذر فتح الاستديو. تحقق من صلاحيات الصور والفيديو');
    }
  }

  Future<void> _recordVoice() async {
    if (_uploading) return;
    final draft = await showDialog<VoiceDraft>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const VoiceRecordingDialog());
    if (draft == null || !mounted) return;
    await _sendMedia(bytes: draft.bytes, extension: 'm4a', type: 'audio');
  }

  void _showAttachMenu() {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.image_rounded),
                  title: const Text('صورة'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage();
                  }),
              ListTile(
                  leading: const Icon(Icons.videocam_rounded),
                  title: const Text('فيديو'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideo();
                  }),
              ListTile(
                  leading: const Icon(Icons.mic_rounded),
                  title: const Text('تسجيل صوتي'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _recordVoice();
                  }),
            ])));
  }

  Future<bool> _confirm(BuildContext ctx, String title, String text,
      String action) async {
    final result = await showDialog<bool>(
        context: ctx,
        builder: (dialog) => AlertDialog(
                title: Text(title),
                content: Text(text),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(dialog, true),
                      child: Text(action))
                ]));
    return result == true;
  }

  Future<void> _kick(BuildContext sheet, Map<String, dynamic> member) async {
    final name = member['name']?.toString() ?? 'العضو';
    final ok = await _confirm(sheet, 'إخراج من اللّمّة؟',
        'سيُخرج $name من اللّمّة ولن يستطيع الانضمام إليها مرة أخرى.', 'إخراج');
    if (!ok) return;
    try {
      await _db.rpc('kick_social_lamma_member', params: {
        'p_lamma': widget.lammaId,
        'p_user': member['user_id'],
      });
      await _loadMembers();
      _notice('تم إخراج $name من اللّمّة');
    } catch (_) {
      _notice('تعذر إخراج العضو. تأكد أنك منشئ اللّمّة.');
    }
  }

  Future<void> _leave(BuildContext sheet) async {
    final ok = await _confirm(sheet, 'مغادرة اللّمّة؟',
        'ستخرج من اللّمّة ولن ترى دردشتها بعد الآن.', 'مغادرة');
    if (!ok) return;
    try {
      await _db.rpc('leave_social_lamma', params: {'p_lamma': widget.lammaId});
      if (!mounted) return;
      Navigator.pop(sheet);
      Navigator.pop(context);
    } catch (e) {
      if (e.toString().contains('creator_cannot_leave')) {
        _notice('منشئ اللّمّة لا يغادرها. يمكنك إنهاؤها من قائمة اللّمات.');
      } else {
        _notice('تعذرت المغادرة. حاول مرة أخرى.');
      }
    }
  }

  Future<void> _showMembers() async {
    await _loadMembers();
    if (!mounted || _isMember == false) return;
    final uid = _db.auth.currentUser?.id;
    await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => StatefulBuilder(builder: (sheet, setLocal) {
              final iAmCreator = _creatorId != null && _creatorId == uid;
              return SafeArea(
                  child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('أعضاء اللّمّة (${_members.length})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16))),
                        Flexible(
                            child: ListView(shrinkWrap: true, children: [
                          for (final m in _members)
                            ListTile(
                                leading: _avatar(m['profile_image']),
                                title: Text(
                                    '${m['name'] ?? 'Zameel'}${m['is_creator'] == true ? ' • المنظّم' : ''}'),
                                trailing: iAmCreator && m['is_creator'] != true
                                    ? IconButton(
                                        tooltip: 'إخراج من اللّمّة',
                                        icon: const Icon(
                                            Icons.person_remove_rounded,
                                            color: Colors.red),
                                        onPressed: () async {
                                          await _kick(sheet, m);
                                          setLocal(() {});
                                        })
                                    : null),
                        ])),
                        if (!iAmCreator)
                          Padding(
                              padding: const EdgeInsets.all(12),
                              child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red),
                                  onPressed: () => _leave(sheet),
                                  icon: const Icon(Icons.logout_rounded),
                                  label: const Text('مغادرة اللّمّة'))),
                      ])));
            }));
  }

  Widget _avatar(Object? image) {
    final url = image?.toString() ?? '';
    final usable = url.startsWith('http');
    return CircleAvatar(
        backgroundImage: usable ? NetworkImage(url) : null,
        child: usable ? null : const Icon(Icons.person));
  }

  Widget _bubble(Map<String, dynamic> item, String? uid) {
    final mine = item['sender_id'] == uid;
    final mediaPath = item['media_url']?.toString() ?? '';
    final mediaType = item['media_type']?.toString() ?? '';
    final senderName = mine ? null : _names[item['sender_id']?.toString() ?? ''];
    final textColor = mine ? Colors.white : null;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine
              ? AppTheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (senderName != null)
            Text(senderName,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary)),
          if (mediaPath.isNotEmpty)
            LammaMediaView165(
                key: ValueKey('lamma-media-$mediaPath'),
                path: mediaPath,
                type: mediaType,
                bucket: _bucket)
          else
            LinkifiedText165(item['body']?.toString() ?? '',
                style: TextStyle(color: textColor),
                linkColor: mine ? Colors.white : AppTheme.primary),
          Text(
              '${chatTime(item['created_at'])}${item['edited_at'] != null ? ' • تم التعديل' : ''}',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontSize: 11,
                  color: mine
                      ? Colors.white70
                      : Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            IconButton(
                tooltip: 'إرفاق',
                onPressed: _uploading ? null : _showAttachMenu,
                icon: _uploading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_circle_outline_rounded)),
            Expanded(
              child: TextField(
                controller: _message,
                focusNode: _composerFocus,
                groupId: _composerFocus,
                onEditingComplete: () {},
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                    counterText: '', hintText: 'اكتب رسالة للّمّة...'),
              ),
            ),
            const SizedBox(width: 8),
            KeepKeyboardSendButton(
                composerFocus: _composerFocus,
                onSend: _send,
                enabled: !_sending,
                busy: _sending),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _db.auth.currentUser?.id;
    final removed = _isMember == false;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (!removed)
              IconButton(
                  tooltip: 'الأعضاء',
                  onPressed: _showMembers,
                  icon: const Icon(Icons.groups_rounded)),
          ],
        ),
        body: removed
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('لم تعد عضواً في هذه اللّمّة',
                        textAlign: TextAlign.center)))
            : Column(
                children: [
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _stream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                              child: Text('تعذر تحميل دردشة اللّمّة.'));
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final messages = chatDatedRows(snapshot.data!);
                        if (messages.isEmpty) {
                          return const Center(
                              child: Text('ابدأوا الحديث في اللّمّة 👋'));
                        }
                        if (messages.length != _lastCount) {
                          _lastCount = messages.length;
                          if (_stickToEnd) _scrollToEnd();
                        }
                        return ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(14),
                          itemCount: messages.length,
                          itemBuilder: (_, index) {
                            final item = messages[index];
                            if (item['date_separator'] == true) {
                              return ChatDateSeparator(
                                  value: item['created_at']);
                            }
                            return _bubble(item, uid);
                          },
                        );
                      },
                    ),
                  ),
                  _composer(),
                ],
              ),
      ),
    );
  }
}

/// One chat attachment (photo, video or voice note) of a Lamma message.
/// The signed link is requested once per widget so scrolling does not flicker.
class LammaMediaView165 extends StatefulWidget {
  const LammaMediaView165(
      {super.key,
      required this.path,
      required this.type,
      required this.bucket});
  final String path;
  final String type;
  final String bucket;

  @override
  State<LammaMediaView165> createState() => _LammaMediaView165State();
}

class _LammaMediaView165State extends State<LammaMediaView165> {
  late Future<String?> _url;

  Future<String?> _sign() async {
    try {
      return await Supabase.instance.client.storage
          .from(widget.bucket)
          .createSignedUrl(widget.path, 3600);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _url = _sign();
  }

  void _openImage(String url) {
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white),
                body: Center(
                    child: InteractiveViewer(child: Image.network(url))))));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
        future: _url,
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (url == null) {
            return TextButton(
                onPressed: () => setState(() => _url = _sign()),
                child: const Text('تعذر فتح المرفق — أعد المحاولة'));
          }
          if (widget.type == 'image') {
            return InkWell(
                onTap: () => _openImage(url),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url,
                        width: 220, height: 180, fit: BoxFit.cover)));
          }
          if (widget.type == 'video') {
            return SizedBox(width: 240, child: VideoPlayerWidget(videoUrl: url));
          }
          return ChatVoicePlayer(key: ValueKey(widget.path), url: url);
        },
      );
}
