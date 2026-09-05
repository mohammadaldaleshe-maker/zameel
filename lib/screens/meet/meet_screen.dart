import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';

// ============================================================
// ZAMEEL MEET SCREEN
// ============================================================

class MeetScreen extends StatefulWidget {
  final String? participantName;
  final String? roomId;
  final bool startImmediately;
  const MeetScreen({super.key, this.participantName, this.roomId, this.startImmediately = false});

  @override
  State<MeetScreen> createState() => _MeetScreenState();
}

class _MeetScreenState extends State<MeetScreen> {
  int selectedTab = 0; // 0 = إنشاء اجتماع, 1 = الانضمام, 2 = الاجتماعات السابقة

  @override
  void initState() {
    super.initState();
    if (widget.startImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MeetingRoomScreen(participantName: widget.participantName, roomId: widget.roomId)));
      });
    }
  }

  final List<Map<String, dynamic>> pastMeetings = [
    {
      'id': 1,
      'title': 'اجتماع فريق البرمجة',
      'date': '2024-06-15',
      'time': '14:30',
      'participants': 12,
      'duration': '1:30',
    },
    {
      'id': 2,
      'title': 'محاضرة قواعد البيانات',
      'date': '2024-06-14',
      'time': '10:00',
      'participants': 45,
      'duration': '2:00',
    },
    {
      'id': 3,
      'title': 'لقاء مع مشرف التخرج',
      'date': '2024-06-13',
      'time': '16:00',
      'participants': 3,
      'duration': '0:45',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.participantName != null ? '${isArabic ? 'مكالمة مع' : 'Call with'} ${widget.participantName}' : '🎥 Zameel Meet',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // ====================================================
            // TABS
            // ====================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _MeetTabButton(
                    text: isArabic ? '➕ إنشاء' : '➕ Create',
                    isSelected: selectedTab == 0,
                    onTap: () {
                      setState(() {
                        selectedTab = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _MeetTabButton(
                    text: isArabic ? '🔗 انضمام' : '🔗 Join',
                    isSelected: selectedTab == 1,
                    onTap: () {
                      setState(() {
                        selectedTab = 1;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _MeetTabButton(
                    text: isArabic ? '📋 سابقة' : '📋 History',
                    isSelected: selectedTab == 2,
                    onTap: () {
                      setState(() {
                        selectedTab = 2;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ====================================================
            // CONTENT
            // ====================================================
            Expanded(
              child: selectedTab == 0
                  ? _buildCreateTab(isArabic)
                  : selectedTab == 1
                      ? _buildJoinTab(isArabic)
                      : _buildHistoryTab(isArabic),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CREATE TAB (إنشاء اجتماع)
  // ============================================================

  Widget _buildCreateTab(bool isArabic) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final TextEditingController timeController = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==============================================
          // صورة توضيحية
          // ==============================================
          Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF18D3C3),
                  Color(0xFF0B9F95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_call_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'ابدأ اجتماعك الآن',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==============================================
          // عنوان الاجتماع
          // ==============================================
          Text(
            isArabic ? '📝 عنوان الاجتماع' : '📝 Meeting Title',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              hintText: isArabic
                  ? 'مثال: اجتماع فريق البرمجة'
                  : 'Example: Programming team meeting',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.title_rounded),
            ),
          ),

          const SizedBox(height: 16),

          // ==============================================
          // التاريخ والوقت
          // ==============================================
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? '📅 التاريخ' : '📅 Date',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dateController,
                      decoration: InputDecoration(
                        hintText: '2024-06-20',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? '⏰ الوقت' : '⏰ Time',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: timeController,
                      decoration: InputDecoration(
                        hintText: '14:30',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.access_time_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ==============================================
          // زر إنشاء الاجتماع
          // ==============================================
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ يرجى إدخال عنوان الاجتماع')),
                  );
                  return;
                }
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) return;

                final roomCode = 'ZM${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
                try {
                  await Supabase.instance.client.from('meeting_rooms').insert({
                    'room_code': roomCode,
                    'host_id': user.id,
                    'title': title,
                    'created_at': DateTime.now().toIso8601String(),
                  });
                } catch (_) {
                  // A valid room code is still usable for the realtime room.
                }
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeetingRoomScreen(
                      participantName: title,
                      roomId: roomCode,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.video_call_rounded),
              label: Text(
                isArabic ? '🚀 إنشاء اجتماع' : '🚀 Create Meeting',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18D3C3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // JOIN TAB (الانضمام إلى اجتماع)
  // ============================================================

  Widget _buildJoinTab(bool isArabic) {
    final TextEditingController codeController = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==============================================
          // صورة توضيحية
          // ==============================================
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF18D3C3),
                  Color(0xFF0B9F95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'انضم إلى اجتماع موجود',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==============================================
          // رمز الاجتماع
          // ==============================================
          Text(
            isArabic ? '🔑 رمز الاجتماع' : '🔑 Meeting Code',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: codeController,
            decoration: InputDecoration(
              hintText: isArabic ? 'مثال: xyz123' : 'Example: xyz123',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),

          const SizedBox(height: 16),

          // ==============================================
          // زر الانضمام
          // ==============================================
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ يرجى إدخال رمز الاجتماع')),
                  );
                  return;
                }
                try {
                  final room = await Supabase.instance.client
                      .from('meeting_rooms')
                      .select('room_code,title')
                      .eq('room_code', code)
                      .maybeSingle();
                  if (room == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('رمز الاجتماع غير موجود')),
                      );
                    }
                    return;
                  }
                } catch (_) {}
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeetingRoomScreen(
                      participantName: code,
                      roomId: code,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.login_rounded),
              label: Text(
                isArabic ? '🔗 انضمام إلى الاجتماع' : '🔗 Join Meeting',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18D3C3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY TAB (الاجتماعات السابقة)
  // ============================================================

  Widget _buildHistoryTab(bool isArabic) {
    if (pastMeetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'لا توجد اجتماعات سابقة' : 'No past meetings',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? 'اجتماعاتك السابقة ستظهر هنا'
                  : 'Your past meetings will appear here',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: pastMeetings.length,
      itemBuilder: (context, index) {
        final meeting = pastMeetings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF18D3C3).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.video_call_rounded,
                color: Color(0xFF18D3C3),
                size: 28,
              ),
            ),
            title: Text(
              meeting['title'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📅 ${meeting['date']} • ⏰ ${meeting['time']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '👥 ${meeting['participants']} مشارك • ⏱️ ${meeting['duration']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isArabic
                          ? '📋 عرض تفاصيل ${meeting['title']}'
                          : '📋 Viewing ${meeting['title']} details',
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// MEET TAB BUTTON
// ============================================================

class _MeetTabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _MeetTabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFF18D3C3)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF18D3C3)
                  : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MEETING ROOM SCREEN (شاشة الاجتماع)
// ============================================================

class MeetingRoomScreen extends StatefulWidget {
  final String? participantName;
  final String? roomId;
  const MeetingRoomScreen({
    super.key,
    this.participantName,
    this.roomId,
  });

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final _chatController = TextEditingController();
  final _chatScroll = ScrollController();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  RealtimeChannel? _signal;
  String? _uid;
  bool _muted = false;
  bool _videoOn = true;
  bool _speakerOn = true;
  bool _connected = false;
  bool _starting = true;
  bool _chatOpen = false;
  bool _screenSharing = false;
  List<String> _chat = [];
  MediaStreamTrack? _cameraTrack;
  bool _initiator = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _resolveInitiator() async {
    final me = _uid;
    final roomId = widget.roomId;
    if (me == null || roomId == null || roomId.isEmpty) {
      _initiator = true;
      return;
    }

    try {
      final room = await Supabase.instance.client
          .from('meeting_rooms')
          .select('host_id')
          .eq('room_code', roomId)
          .maybeSingle();
      if (room != null) {
        _initiator = room['host_id']?.toString() == me;
        return;
      }
    } catch (_) {}

    try {
      final rows = await Supabase.instance.client
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', roomId)
          .order('user_id');
      final ids = rows
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isNotEmpty) {
        _initiator = ids.first == me;
        return;
      }
    } catch (_) {}

    _initiator = true;
  }

  Future<void> _start() async {
    final db = Supabase.instance.client;
    _uid = db.auth.currentUser?.id;
    if (_uid == null) {
      if (mounted) setState(() => _starting = false);
      return;
    }

    await _resolveInitiator();

    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });
      _localRenderer.srcObject = _localStream;
      _cameraTrack = _localStream?.getVideoTracks().isNotEmpty == true
          ? _localStream!.getVideoTracks().first
          : null;

      _pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      });

      for (final track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }

      _pc!.onTrack = (event) {
        if (event.streams.isNotEmpty && mounted) {
          _remoteRenderer.srcObject = event.streams.first;
          setState(() => _connected = true);
        }
      };

      _pc!.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        _signal?.sendBroadcastMessage(
          event: 'signal',
          payload: {
            'type': 'candidate',
            'from': _uid,
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      };

      _signal = db.channel(
        'zameel-meet:${widget.roomId ?? 'room'}',
      );
      _signal!
          .onBroadcast(
            event: 'signal',
            callback: (payload) => _handleSignal(
              Map<String, dynamic>.from(payload),
            ),
          )
          .onBroadcast(
            event: 'chat',
            callback: (payload) => _onChatSignal(
              Map<String, dynamic>.from(payload),
            ),
          )
          .subscribe();

      await Future<void>.delayed(const Duration(milliseconds: 700));
      await _signal?.sendBroadcastMessage(
          event: 'signal',
        payload: {'type': 'ready', 'from': _uid},
      );

      if (mounted) setState(() => _starting = false);

      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (_initiator) {
        final offer = await _pc!.createOffer({});
        await _pc!.setLocalDescription(offer);
        await _signal?.sendBroadcastMessage(
          event: 'signal',
          payload: {
            'type': 'offer',
            'from': _uid,
            'sdp': offer.sdp,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _starting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر بدء الاجتماع: $e')),
        );
      }
    }
  }

  Future<void> _handleSignal(Map<String, dynamic> msg) async {
    if (msg['from']?.toString() == _uid) return;
    final pc = _pc;
    final signal = _signal;
    if (pc == null || signal == null) return;

    try {
      switch (msg['type']) {
        case 'ready':
          if (_initiator) {
            final offer = await pc.createOffer({});
            await pc.setLocalDescription(offer);
            await signal.sendBroadcastMessage(
          event: 'signal',
              payload: {
                'type': 'offer',
                'from': _uid,
                'sdp': offer.sdp,
              },
            );
          }
          break;
        case 'offer':
          await pc.setRemoteDescription(
            RTCSessionDescription(msg['sdp']?.toString() ?? '', 'offer'),
          );
          final answer = await pc.createAnswer({});
          await pc.setLocalDescription(answer);
          await signal.sendBroadcastMessage(
          event: 'signal',
            payload: {
              'type': 'answer',
              'from': _uid,
              'sdp': answer.sdp,
            },
          );
          break;
        case 'answer':
          await pc.setRemoteDescription(
            RTCSessionDescription(msg['sdp']?.toString() ?? '', 'answer'),
          );
          break;
        case 'candidate':
          final c = msg['candidate']?.toString();
          if (c != null && c.isNotEmpty) {
            await pc.addCandidate(
              RTCIceCandidate(
                c,
                msg['sdpMid']?.toString(),
                (msg['sdpMLineIndex'] as num?)?.toInt(),
              ),
            );
          }
          break;
      }
    } catch (e) {
      debugPrint('Meeting signaling error: $e');
    }
  }

  Future<void> _toggleMute() async {
    final tracks = _localStream?.getAudioTracks() ?? [];
    for (final track in tracks) {
      track.enabled = _muted;
    }
    if (mounted) setState(() => _muted = !_muted);
  }

  Future<void> _toggleVideo() async {
    final tracks = _localStream?.getVideoTracks() ?? [];
    for (final track in tracks) {
      track.enabled = !_videoOn;
    }
    if (mounted) setState(() => _videoOn = !_videoOn);
  }

  Future<void> _switchCamera() async {
    if (_cameraTrack == null) return;
    try {
      await Helper.switchCamera(_cameraTrack!);
    } catch (_) {}
  }

  Future<void> _toggleSpeaker() async {
    try {
      await Helper.setSpeakerphoneOn(!_speakerOn);
    } catch (_) {}
    if (mounted) setState(() => _speakerOn = !_speakerOn);
  }

  Future<void> _toggleScreenShare() async {
    if (_localStream == null || _pc == null) return;
    try {
      final senders = await _pc!.getSenders();
      final videoSender = senders.firstWhere(
        (s) => s.track?.kind == 'video',
      );
      if (!_screenSharing) {
        final screen = await navigator.mediaDevices.getDisplayMedia({
          'audio': false,
          'video': true,
        });
        final screenTrack = screen.getVideoTracks().first;
        await videoSender.replaceTrack(screenTrack);
        if (mounted) {
          setState(() => _screenSharing = true);
        }
      } else {
        final camera = _cameraTrack;
        if (camera != null) await videoSender.replaceTrack(camera);
        if (mounted) setState(() => _screenSharing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('مشاركة الشاشة غير متاحة: $e')),
        );
      }
    }
  }

  Future<void> _sendChat() async {
    final value = _chatController.text.trim();
    if (value.isEmpty) return;
    _chatController.clear();
    setState(() => _chat.add(value));
    await _signal?.sendBroadcastMessage(
          event: 'chat',
      payload: {'from': _uid, 'message': value},
    );
  }

  void _onChatSignal(Map<String, dynamic> msg) {
    if (msg['from']?.toString() == _uid) return;
    final value = msg['message']?.toString();
    if (value != null && value.isNotEmpty && mounted) {
      setState(() => _chat.add(value));
    }
  }

  Future<void> _hangUp() async {
    try {
      for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        await track.stop();
      }
      await _localStream?.dispose();
      await _pc?.close();
      _signal?.unsubscribe();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _signal?.unsubscribe();
    _pc?.close();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _chatController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: _connected
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : const Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 100,
                        color: Colors.white24,
                      ),
                    ),
            ),
            if (_localRenderer.srcObject != null)
              Positioned(
                top: 46,
                right: 16,
                width: 120,
                height: 170,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _hangUp,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          widget.participantName ?? 'Zameel Meet',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _chatOpen = !_chatOpen),
                        icon: const Icon(Icons.chat_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  if (_starting)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else if (!_connected)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        ar ? 'بانتظار الزميل للانضمام...' : 'Waiting for colleague...',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _control(
                          icon: _muted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          onTap: _toggleMute,
                        ),
                        _control(
                          icon: _videoOn
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          onTap: _toggleVideo,
                        ),
                        _control(
                          icon: Icons.cameraswitch_rounded,
                          onTap: _switchCamera,
                        ),
                        _control(
                          icon: _speakerOn
                              ? Icons.volume_up_rounded
                              : Icons.hearing_disabled_rounded,
                          onTap: _toggleSpeaker,
                        ),
                        _control(
                          icon: _screenSharing
                              ? Icons.stop_screen_share_rounded
                              : Icons.screen_share_rounded,
                          onTap: _toggleScreenShare,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_chatOpen)
              Positioned(
                left: 12,
                right: 12,
                bottom: 96,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 150,
                          child: ListView.builder(
                            controller: _chatScroll,
                            itemCount: _chat.length,
                            itemBuilder: (_, i) => Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Text(_chat[i]),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _chatController,
                                decoration: const InputDecoration(
                                  hintText: 'رسالة...',
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _control({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFF18D3C3),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
