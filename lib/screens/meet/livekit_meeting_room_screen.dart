import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/language_provider.dart';
import '../../services/screen_awake_service.dart';
import '../../theme/app_theme.dart';

class LiveKitMeetingRoomScreen extends StatefulWidget {
  final String roomCode;
  final String title;
  final bool isHost;
  final bool initialVideoOn;
  final bool initialMicOn;

  const LiveKitMeetingRoomScreen({
    super.key,
    required this.roomCode,
    required this.title,
    required this.isHost,
    required this.initialVideoOn,
    required this.initialMicOn,
  });

  @override
  State<LiveKitMeetingRoomScreen> createState() =>
      _LiveKitMeetingRoomScreenState();
}

class _LiveKitMeetingRoomScreenState
    extends State<LiveKitMeetingRoomScreen> {
  static const _chatTopic = 'zameel.meet.chat';

  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  final List<_MeetingChatMessage> _messages = <_MeetingChatMessage>[];

  bool _loading = true;
  bool _leaving = false;
  bool _chatOpen = false;
  bool _micOn = true;
  bool _videoOn = true;
  bool _speakerOn = true;
  bool _isHost = false;
  String? _error;
  lk.CameraPosition _cameraPosition = lk.CameraPosition.front;

  @override
  void initState() {
    super.initState();
    _micOn = widget.initialMicOn;
    _videoOn = widget.initialVideoOn;
    _isHost = widget.isHost;
    ScreenAwakeService.enterPersistent();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'livekit-token',
        body: {
          'action': 'token',
          'room_code': widget.roomCode,
        },
      );
      final raw = response.data;
      if (raw is! Map) throw StateError('invalid_livekit_token_response');
      if (raw['error'] != null) {
        throw StateError(raw['error'].toString());
      }
      final serverUrl = raw['server_url']?.toString() ?? '';
      final token = raw['token']?.toString() ?? '';
      if (serverUrl.isEmpty || token.isEmpty) {
        throw StateError('livekit_not_configured');
      }
      _isHost = raw['is_host'] == true;

      final room = lk.Room(
        roomOptions: const lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      room.addListener(_onRoomChanged);
      _listener = room.createListener()
        ..on<lk.DataReceivedEvent>(_handleDataReceived)
        ..on<lk.RoomDisconnectedEvent>((event) {
          if (!mounted || _leaving) return;
          setState(() {
            _error = 'meeting_disconnected';
          });
        });

      await room.prepareConnection(serverUrl, token);
      await room.connect(serverUrl, token);
      _room = room;

      final local = room.localParticipant;
      if (local != null) {
        try {
          await local.setMicrophoneEnabled(_micOn);
        } catch (_) {
          _micOn = false;
        }
        if (_videoOn) {
          try {
            await local.setCameraEnabled(
              true,
              cameraCaptureOptions: const lk.CameraCaptureOptions(
                cameraPosition: lk.CameraPosition.front,
              ),
            );
          } catch (_) {
            _videoOn = false;
          }
        }
      }
      try {
        await lk.AudioManager.instance.setSpeakerOutputPreferred(true);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } on FunctionException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  List<lk.Participant> get _participants {
    final room = _room;
    if (room == null) return const <lk.Participant>[];
    final result = <lk.Participant>[];
    final local = room.localParticipant;
    if (local != null) result.add(local);
    final remotes = room.remoteParticipants.values.toList()
      ..sort((a, b) {
        if (a.isSpeaking != b.isSpeaking) return a.isSpeaking ? -1 : 1;
        final aSpoke = a.lastSpokeAt?.millisecondsSinceEpoch ?? 0;
        final bSpoke = b.lastSpokeAt?.millisecondsSinceEpoch ?? 0;
        return bSpoke.compareTo(aSpoke);
      });
    result.addAll(remotes);
    return result;
  }

  Future<void> _toggleMic() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    final next = !_micOn;
    try {
      await local.setMicrophoneEnabled(next);
      if (mounted) setState(() => _micOn = next);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleVideo() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    final next = !_videoOn;
    try {
      await local.setCameraEnabled(
        next,
        cameraCaptureOptions: lk.CameraCaptureOptions(
          cameraPosition: _cameraPosition,
        ),
      );
      if (mounted) setState(() => _videoOn = next);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _switchCamera() async {
    final local = _room?.localParticipant;
    if (local == null || !_videoOn) return;
    try {
      final publication = local.getTrackPublicationBySource(lk.TrackSource.camera);
      final track = publication?.track;
      if (track is lk.LocalVideoTrack) {
        _cameraPosition = _cameraPosition.switched();
        await track.setCameraPosition(_cameraPosition);
        if (mounted) setState(() {});
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    try {
      await lk.AudioManager.instance.setSpeakerOutputPreferred(next);
      if (mounted) setState(() => _speakerOn = next);
    } catch (error) {
      _showError(error);
    }
  }

  void _handleDataReceived(lk.DataReceivedEvent event) {
    if (event.topic != _chatTopic) return;
    try {
      final decoded = jsonDecode(utf8.decode(event.data));
      if (decoded is! Map) return;
      final text = decoded['text']?.toString().trim() ?? '';
      if (text.isEmpty) return;
      final sender = decoded['sender']?.toString().trim();
      if (!mounted) return;
      setState(() {
        _messages.add(
          _MeetingChatMessage(
            sender: sender?.isNotEmpty == true
                ? sender!
                : (event.participant?.name.isNotEmpty == true
                    ? event.participant!.name
                    : 'Zameel'),
            text: text,
            mine: false,
          ),
        );
      });
      _scrollChatToBottom();
    } catch (_) {}
  }

  Future<void> _sendChat() async {
    final text = _chatController.text.trim();
    final local = _room?.localParticipant;
    if (text.isEmpty || local == null) return;
    _chatController.clear();
    final sender = local.name.isNotEmpty ? local.name : 'Zameel';
    if (mounted) {
      setState(() {
        _messages.add(_MeetingChatMessage(sender: sender, text: text, mine: true));
      });
    }
    _scrollChatToBottom();
    try {
      await local.publishData(
        utf8.encode(jsonEncode({'sender': sender, 'text': text})),
        reliable: true,
        topic: _chatTopic,
      );
    } catch (error) {
      _showError(error);
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.animateTo(
        _chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _hostMute(lk.Participant participant) async {
    if (!_isHost || participant is! lk.RemoteParticipant) return;
    final audioPubs = participant.audioTrackPublications;
    if (audioPubs.isEmpty) return;
    final publication = audioPubs.first;
    try {
      await Supabase.instance.client.functions.invoke(
        'livekit-token',
        body: {
          'action': 'mute',
          'room_code': widget.roomCode,
          'participant_identity': participant.identity,
          'track_sid': publication.sid,
        },
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _hostRemove(lk.Participant participant) async {
    if (!_isHost || participant is! lk.RemoteParticipant) return;
    try {
      await Supabase.instance.client.functions.invoke(
        'livekit-token',
        body: {
          'action': 'remove',
          'room_code': widget.roomCode,
          'participant_identity': participant.identity,
        },
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _leave({bool endForEveryone = false}) async {
    if (_leaving) return;
    if (endForEveryone && _isHost) {
      final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(ar ? 'إنهاء الاجتماع؟' : 'End meeting?'),
          content: Text(
            ar
                ? 'سيتم إنهاء الغرفة وفصل جميع المشاركين.'
                : 'The room will close and all participants will be disconnected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(ar ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(ar ? 'إنهاء للجميع' : 'End for everyone'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    _leaving = true;
    try {
      if (endForEveryone && _isHost) {
        try {
          await Supabase.instance.client.functions.invoke(
            'livekit-token',
            body: {'action': 'end', 'room_code': widget.roomCode},
          );
        } catch (_) {}
      }
      try {
        await Supabase.instance.client.rpc(
          'leave_zameel_meeting',
          params: {'target_room_code': widget.roomCode},
        );
      } catch (_) {}
      await _room?.disconnect();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  String _friendlyError(bool ar) {
    final value = (_error ?? '').toLowerCase();
    if (value.contains('livekit_not_configured')) {
      return ar
          ? 'خادم الاجتماعات المتعددة غير مهيأ بعد. أضف إعدادات LiveKit إلى Supabase ثم أعد المحاولة.'
          : 'The multi-participant meeting server is not configured yet. Add the LiveKit secrets in Supabase and try again.';
    }
    if (value.contains('meeting_ended')) {
      return ar ? 'انتهى هذا الاجتماع.' : 'This meeting has ended.';
    }
    if (value.contains('meeting_disconnected')) {
      return ar
          ? 'انقطع الاتصال بغرفة الاجتماع. تحقق من الشبكة ثم أعد الدخول.'
          : 'The meeting connection was lost. Check your network and rejoin.';
    }
    return ar
        ? 'تعذر الاتصال بغرفة الاجتماع متعددة المشاركين.'
        : 'Could not connect to the multi-participant meeting room.';
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoomChanged);
    final listener = _listener;
    if (listener != null) unawaited(listener.dispose());
    if (!_leaving) {
      unawaited(
        Supabase.instance.client
            .rpc(
              'leave_zameel_meeting',
              params: {'target_room_code': widget.roomCode},
            )
            .then<void>((_) {})
            .catchError((_) {}),
      );
    }
    final room = _room;
    if (room != null) unawaited(room.dispose().then<void>((_) {}));
    _chatController.dispose();
    _chatScroll.dispose();
    ScreenAwakeService.exitPersistent();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    final participants = _participants;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF071819),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(ar, participants.length),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : _error != null
                            ? _buildError(ar)
                            : _buildGrid(participants, ar),
                  ),
                  if (!_loading && _error == null) _buildControls(ar),
                ],
              ),
              if (_chatOpen && !_loading && _error == null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 94,
                  child: _buildChat(ar),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool ar, int participantCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _leave(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  ar
                      ? '$participantCount مشارك • ${widget.roomCode}'
                      : '$participantCount participants • ${widget.roomCode}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_isHost)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.workspace_premium_rounded, color: Colors.amber),
            ),
          IconButton(
            onPressed: () => setState(() => _chatOpen = !_chatOpen),
            icon: Icon(
              _chatOpen ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<lk.Participant> participants, bool ar) {
    if (participants.isEmpty) {
      return Center(
        child: Text(
          ar ? 'بانتظار المشاركين...' : 'Waiting for participants...',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = participants.length == 1
            ? 1
            : width >= 1100
                ? 4
                : width >= 720
                    ? 3
                    : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: participants.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns == 1 ? 1.35 : 0.86,
          ),
          itemBuilder: (context, index) {
            final participant = participants[index];
            final local = participant is lk.LocalParticipant;
            return _LiveKitParticipantTile(
              key: ValueKey('${participant.identity}-$local'),
              participant: participant,
              isLocal: local,
              canModerate: _isHost && !local,
              onMute: () => _hostMute(participant),
              onRemove: () => _hostRemove(participant),
              isArabic: ar,
            );
          },
        );
      },
    );
  }

  Widget _buildControls(bool ar) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
      decoration: const BoxDecoration(
        color: Color(0xCC0C2324),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          _control(
            icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: ar ? 'الميكروفون' : 'Mic',
            onTap: _toggleMic,
          ),
          _control(
            icon: _videoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            label: ar ? 'الكاميرا' : 'Camera',
            onTap: _toggleVideo,
          ),
          _control(
            icon: Icons.cameraswitch_rounded,
            label: ar ? 'تبديل' : 'Flip',
            onTap: _switchCamera,
          ),
          _control(
            icon: _speakerOn ? Icons.volume_up_rounded : Icons.hearing_disabled_rounded,
            label: ar ? 'الصوت' : 'Speaker',
            onTap: _toggleSpeaker,
          ),
          _control(
            icon: Icons.logout_rounded,
            label: ar ? 'مغادرة' : 'Leave',
            onTap: () => _leave(),
            danger: true,
          ),
          if (_isHost)
            _control(
              icon: Icons.stop_circle_outlined,
              label: ar ? 'إنهاء للجميع' : 'End all',
              onTap: () => _leave(endForEveryone: true),
              danger: true,
            ),
        ],
      ),
    );
  }

  Widget _control({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: danger ? Colors.redAccent : AppTheme.primary.withOpacity(0.9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChat(bool ar) {
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 190,
              child: _messages.isEmpty
                  ? Center(
                      child: Text(ar ? 'لا توجد رسائل بعد' : 'No messages yet'),
                    )
                  : ListView.builder(
                      controller: _chatScroll,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return Align(
                          alignment: message.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: message.mine
                                  ? AppTheme.primary.withOpacity(0.14)
                                  : AppTheme.muted.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.sender,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(message.text),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    onSubmitted: (_) => _sendChat(),
                    decoration: InputDecoration(
                      hintText: ar ? 'رسالة للاجتماع...' : 'Message the meeting...',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sendChat,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(bool ar) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white54, size: 64),
            const SizedBox(height: 14),
            Text(
              _friendlyError(ar),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _connect();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(ar ? 'إعادة المحاولة' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveKitParticipantTile extends StatefulWidget {
  final lk.Participant participant;
  final bool isLocal;
  final bool canModerate;
  final VoidCallback onMute;
  final VoidCallback onRemove;
  final bool isArabic;

  const _LiveKitParticipantTile({
    super.key,
    required this.participant,
    required this.isLocal,
    required this.canModerate,
    required this.onMute,
    required this.onRemove,
    required this.isArabic,
  });

  @override
  State<_LiveKitParticipantTile> createState() =>
      _LiveKitParticipantTileState();
}

class _LiveKitParticipantTileState extends State<_LiveKitParticipantTile> {
  @override
  void initState() {
    super.initState();
    widget.participant.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _LiveKitParticipantTile oldWidget) {
    if (oldWidget.participant != widget.participant) {
      oldWidget.participant.removeListener(_changed);
      widget.participant.addListener(_changed);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.participant.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  lk.VideoTrack? _activeVideoTrack() {
    final publications = widget.participant.videoTrackPublications;
    for (final publication in publications) {
      if (publication.isScreenShare && !publication.muted) {
        final track = publication.track;
        if (track is lk.VideoTrack) return track;
      }
    }
    for (final publication in publications) {
      if (!publication.isScreenShare && !publication.muted) {
        final track = publication.track;
        if (track is lk.VideoTrack) return track;
      }
    }
    return null;
  }

  bool get _micMuted {
    final pubs = widget.participant.audioTrackPublications;
    if (pubs.isEmpty) return true;
    return pubs.every((publication) => publication.muted);
  }

  @override
  Widget build(BuildContext context) {
    final track = _activeVideoTrack();
    final name = widget.participant.name.isNotEmpty
        ? widget.participant.name
        : (widget.isArabic ? 'زميل' : 'Zameel');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF102829),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.participant.isSpeaking
              ? AppTheme.primary
              : Colors.white12,
          width: widget.participant.isSpeaking ? 3 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (track != null)
            lk.VideoTrackRenderer(
              track,
              fit: lk.VideoViewFit.cover,
            )
          else
            const Center(
              child: Icon(Icons.person_rounded, size: 70, color: Colors.white24),
            ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    size: 15,
                    color: _micMuted ? Colors.redAccent : Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      widget.isLocal
                          ? '${widget.isArabic ? 'أنت' : 'You'} • $name'
                          : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (widget.canModerate)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 19),
                      onSelected: (value) {
                        if (value == 'mute') widget.onMute();
                        if (value == 'remove') widget.onRemove();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'mute',
                          child: Text(widget.isArabic ? 'كتم الميكروفون' : 'Mute microphone'),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(widget.isArabic ? 'إزالة من الاجتماع' : 'Remove from meeting'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (widget.participant.isSpeaking)
            const Positioned(
              top: 8,
              left: 8,
              child: Icon(Icons.graphic_eq_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _MeetingChatMessage {
  final String sender;
  final String text;
  final bool mine;

  const _MeetingChatMessage({
    required this.sender,
    required this.text,
    required this.mine,
  });
}
