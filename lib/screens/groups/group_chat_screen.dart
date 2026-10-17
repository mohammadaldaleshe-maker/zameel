import '../../widgets/keep_keyboard_send_button.dart';
import '../../widgets/chat_timestamp.dart';
import 'package:zameel/theme/appearance_controller.dart';
import 'package:zameel/widgets/verified_name.dart';
import 'package:flutter/material.dart';
import '../../services/feature_control.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../services/remaining_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat_voice_widgets.dart';
import '../../widgets/linkified_text165.dart';
import '../../widgets/video_player_widget.dart';
import 'group_invite_sheet.dart';
import 'group_members_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final bool isOwner;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.isOwner = false,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _composerFocus = FocusNode();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _uploading = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel =
        RemainingServices.subscribeToGroupMessages(widget.groupId, _load);
  }

  Future<void> _load() async {
    try {
      final rows = await RemainingServices.groupMessages(widget.groupId);
      if (!mounted) return;
      setState(() {
        _messages = chatDatedRows(rows);
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await RemainingServices.sendGroupMessage(widget.groupId, text);
      _controller.clear();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(FeatureControl.errorMessage(
                error, 'تعذر إرسال الرسالة إلى المجموعة'))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _chooseAttachment() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('صورة من الاستديو'),
              onTap: () => Navigator.pop(sheetContext, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('فيديو من الاستديو'),
              onTap: () => Navigator.pop(sheetContext, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('رسالة صوتية'),
              onTap: () => Navigator.pop(sheetContext, 'voice'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || kind == null) return;
    if (kind == 'voice') {
      await _recordVoice();
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = kind == 'image'
          ? await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
              maxWidth: 1920,
            )
          : await picker.pickVideo(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      await _sendAttachment(bytes, picked.name, kind);
    } catch (_) {
      _notice('تعذر فتح الاستديو. تحقق من صلاحيات الصور والفيديو');
    }
  }

  Future<void> _recordVoice() async {
    if (_uploading) return;
    final draft = await showDialog<VoiceDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const VoiceRecordingDialog(),
    );
    if (draft == null || !mounted) return;
    await _sendAttachment(
      draft.bytes,
      'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      'audio',
    );
  }

  String _mimeFor(String kind, String filename) {
    final extension =
        filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    if (kind == 'audio') return 'audio/mp4';
    if (kind == 'image') {
      if (extension == 'png' || extension == 'webp' || extension == 'gif') {
        return 'image/$extension';
      }
      return 'image/jpeg';
    }
    if (extension == 'mov') return 'video/quicktime';
    if (extension == 'webm') return 'video/webm';
    return 'video/mp4';
  }

  Future<void> _sendAttachment(
      Uint8List bytes, String filename, String kind) async {
    if (_uploading) return;
    if (bytes.isEmpty) {
      _notice('تعذر قراءة الملف المختار');
      return;
    }
    if (bytes.length > 20 * 1024 * 1024) {
      _notice('الحد الأقصى للمرفق 20 ميجابايت');
      return;
    }
    setState(() => _uploading = true);
    try {
      final path = await RemainingServices.uploadGroupAttachment(
        widget.groupId,
        bytes,
        filename,
        _mimeFor(kind, filename),
      );
      await RemainingServices.sendGroupMessage(
        widget.groupId,
        kind == 'image'
            ? 'صورة'
            : kind == 'video'
                ? 'فيديو'
                : 'رسالة صوتية',
        mediaPath: path,
        mediaType: kind,
      );
      await _load();
    } catch (error) {
      _notice(RemainingServices.groupErrorText(error, 'تعذر إرسال المرفق'));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _messageBody(Map<String, dynamic> message, bool isMe) {
    final path = message['media_url']?.toString() ?? '';
    final type = message['media_type']?.toString() ?? '';
    final textColor = isMe ? Colors.white : AppTheme.adaptiveText;
    if (path.isEmpty || type.isEmpty) {
      return LinkifiedText165(
        message['content']?.toString() ?? '',
        style: TextStyle(color: textColor, fontSize: 15),
        linkColor: isMe ? Colors.white : AppTheme.primary,
      );
    }
    return FutureBuilder<String?>(
      future: RemainingServices.groupAttachmentUrl(path),
      initialData: RemainingServices.cachedGroupAttachmentUrl(path),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return Text('تعذر فتح المرفق', style: TextStyle(color: textColor));
        }
        if (type == 'image') {
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _GroupImageViewer(url: url)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url,
                  width: 220, height: 180, fit: BoxFit.cover),
            ),
          );
        }
        if (type == 'video') {
          return SizedBox(width: 240, child: VideoPlayerWidget(videoUrl: url));
        }
        return ChatVoicePlayer(key: ValueKey(message['id']), url: url);
      },
    );
  }

  @override
  void dispose() {
    RemainingServices.removeChannel(_channel);
    _controller.dispose();
    _composerFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final me = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            tooltip: 'دعوة',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => showGroupInviteSheet(
              context,
              groupId: widget.groupId,
              groupName: widget.groupName,
              isOwner: widget.isOwner,
            ),
          ),
          IconButton(
            tooltip: 'الأعضاء',
            icon: const Icon(Icons.people_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupMembersScreen(
                  groupId: widget.groupId,
                  groupName: widget.groupName,
                  isOwner: widget.isOwner,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('لا توجد رسائل بعد'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          if (message['date_separator'] == true)
                            return ChatDateSeparator(
                                value: message['created_at']);
                          final isMe = message['user_id']?.toString() == me;
                          final name = message['sender_name']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true
                              ? message['sender_name'].toString().trim()
                              : 'زميل';
                          final created = DateTime.tryParse(
                            message['created_at']?.toString() ?? '',
                          )?.toLocal();
                          return Align(
                            alignment: isMe
                                ? AlignmentDirectional.centerEnd
                                : AlignmentDirectional.centerStart,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 340),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppTheme.primary
                                    : AppTheme.adaptiveSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: isMe
                                    ? null
                                    : Border.all(
                                        color: AppTheme.adaptiveMuted.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  VerifiedName(
                                      userId: message['user_id']?.toString(),
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isMe
                                              ? Colors.white
                                              : AppTheme.adaptiveText,
                                        ),
                                      )),
                                  const SizedBox(height: 3),
                                  _messageBody(message, isMe),
                                  if (created != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${DateFormat('dd/MM/yyyy • HH:mm').format(created)}${message['edited_at'] != null ? ' • تم التعديل' : ''}',
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white70
                                            : AppTheme.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'إرفاق',
                    onPressed: _uploading ? null : _chooseAttachment,
                    icon: _uploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_circle_outline_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _composerFocus,
                      groupId: _composerFocus,
                      onEditingComplete: () {},
                      style: TextStyle(color: AppTheme.adaptiveText),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة للمجموعة...',
                        hintStyle: TextStyle(color: AppTheme.adaptiveSecondary),
                        filled: true,
                        fillColor: AppTheme.adaptiveSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
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
          ),
        ],
      ),
    );
  }
}

class _GroupImageViewer extends StatelessWidget {
  final String url;

  const _GroupImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
