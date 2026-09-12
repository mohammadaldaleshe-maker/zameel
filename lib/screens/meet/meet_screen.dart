import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../providers/language_provider.dart';
import '../../config.dart';
import '../../l10n/translations.dart';
import 'package:zameel/theme/app_theme.dart';

// ============================================================
// ZAMEEL MEET SCREEN
// ============================================================

class MeetScreen extends StatefulWidget {
  final String? participantName;
  final String? roomId;
  final bool startImmediately;
  final bool startWithVideo;
  final bool? isInitiator;
  const MeetScreen({
    super.key,
    this.participantName,
    this.roomId,
    this.startImmediately = false,
    this.startWithVideo = true,
    this.isInitiator,
  });

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MeetingRoomScreen(
              participantName: widget.participantName,
              roomId: widget.roomId,
              startWithVideo: widget.startWithVideo,
              isInitiator: widget.isInitiator,
            ),
          ),
        );
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
                  AppTheme.primary,
                  AppTheme.primaryDark,
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
                backgroundColor: AppTheme.primary,
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
                  AppTheme.primary,
                  AppTheme.primaryDark,
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
                backgroundColor: AppTheme.primary,
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
              color: AppTheme.muted.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'لا توجد اجتماعات سابقة' : 'No past meetings',
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.muted.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? 'اجتماعاتك السابقة ستظهر هنا'
                  : 'Your past meetings will appear here',
              style: TextStyle(
                color: AppTheme.muted.shade500,
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
              color: AppTheme.muted.shade200,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.video_call_rounded,
                color: AppTheme.primary,
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
                    color: AppTheme.muted.shade600,
                  ),
                ),
                Text(
                  '👥 ${meeting['participants']} مشارك • ⏱️ ${meeting['duration']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted.shade500,
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
                color: AppTheme.muted,
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
                    ? AppTheme.primary
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
                  ? AppTheme.primary
                  : AppTheme.muted.shade600,
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
  final bool startWithVideo;
  final bool? isInitiator;
  const MeetingRoomScreen({
    super.key,
    this.participantName,
    this.roomId,
    this.startWithVideo = true,
    this.isInitiator,
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
  MediaStream? _remoteStream;
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

  // Direct-call signaling state.  Broadcast messages are ephemeral, so do not
  // send the initial SDP until the Realtime websocket confirms SUBSCRIBED.
  // ICE candidates that arrive before the remote SDP are queued and flushed
  // afterwards instead of being lost.
  bool _signalSubscribed = false;
  bool _remoteDescriptionSet = false;
  bool _makingOffer = false;
  bool _offerSent = false;
  String? _lastOfferSdp;
  String? _lastAnswerSdp;
  Timer? _readyTimer;
  Timer? _offerRetryTimer;
  Timer? _signalPollTimer;
  Timer? _connectionWatchdog;
  Completer<void>? _iceGatheringCompleter;
  int _lastSignalRowId = 0;
  final List<RTCIceCandidate> _pendingRemoteCandidates = <RTCIceCandidate>[];
  final Set<String> _handledSignalIds = <String>{};
  String _connectionStateLabel = 'new';
  String _iceStateLabel = 'new';

  @override
  void initState() {
    super.initState();
    _videoOn = widget.startWithVideo;
    _start();
  }

  Future<void> _resolveInitiator() async {
    if (widget.isInitiator != null) {
      _initiator = widget.isInitiator!;
      return;
    }
    final me = _uid;
    final roomId = widget.roomId;
    if (me == null || roomId == null || roomId.isEmpty) {
      _initiator = true;
      return;
    }

    try {
      final directCall = await Supabase.instance.client
          .from('direct_call_sessions')
          .select('caller_id')
          .eq('room_id', roomId)
          .maybeSingle();
      if (directCall != null) {
        _initiator = directCall['caller_id']?.toString() == me;
        return;
      }
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
        'video': widget.startWithVideo
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      });
      _localRenderer.srcObject = _localStream;
      _remoteStream = await createLocalMediaStream('zameel_remote_${widget.roomId ?? 'room'}');
      _remoteRenderer.srcObject = _remoteStream;
      _cameraTrack = _localStream?.getVideoTracks().isNotEmpty == true
          ? _localStream!.getVideoTracks().first
          : null;

      final iceServers = <Map<String, dynamic>>[
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun3.l.google.com:19302'},
      ];
      if (ZameelConfig.webrtcTurnUrl.trim().isNotEmpty) {
        iceServers.add({
          'urls': ZameelConfig.webrtcTurnUrl,
          'username': ZameelConfig.webrtcTurnUsername,
          'credential': ZameelConfig.webrtcTurnCredential,
        });
      }
      _pc = await createPeerConnection({
        'iceServers': iceServers,
        'sdpSemantics': 'unified-plan',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
      });

      for (final track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }

      _pc!.onTrack = (event) async {
        debugPrint('Zameel WebRTC onTrack kind=${event.track.kind} streams=${event.streams.length}');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams.first;
          _remoteRenderer.srcObject = event.streams.first;
        } else {
          // Unified Plan may deliver a track without a MediaStream wrapper on
          // some Android/Web combinations. Attach the track to our own remote
          // stream so audio/video is still rendered instead of being dropped.
          final remote = _remoteStream;
          if (remote != null) {
            try {
              await remote.addTrack(event.track);
              _remoteRenderer.srcObject = remote;
            } catch (e) {
              debugPrint('Zameel WebRTC remote track attach error: $e');
            }
          }
        }
        _markConnected();
      };

      _pc!.onConnectionState = (state) {
        _connectionStateLabel = state.toString().split('.').last;
        debugPrint('Zameel WebRTC connectionState=$_connectionStateLabel room=${widget.roomId}');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _markConnected();
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          if (mounted && _connected) setState(() => _connected = false);
        }
      };

      _pc!.onIceConnectionState = (state) {
        _iceStateLabel = state.toString().split('.').last;
        debugPrint('Zameel WebRTC iceConnectionState=$_iceStateLabel room=${widget.roomId}');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          _markConnected();
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          // ICE can fail transiently while switching Wi-Fi/mobile networks.
          // Restarting ICE is safe and forces a fresh candidate exchange.
          _restartIce();
        }
      };

      _pc!.onIceGatheringState = (state) {
        debugPrint('Zameel WebRTC iceGatheringState=${state.toString().split('.').last} room=${widget.roomId}');
        // flutter_webrtc renamed some enum constants between releases.  The
        // stable string value remains "complete", so use it here to keep the
        // call flow compatible with the package version resolved by pub.
        if (state.toString().split('.').last.toLowerCase().contains('complete')) {
          final completer = _iceGatheringCompleter;
          if (completer != null && !completer.isCompleted) completer.complete();
        }
      };

      _pc!.onSignalingState = (state) {
        debugPrint('Zameel WebRTC signalingState=${state.toString().split('.').last} room=${widget.roomId}');
      };

      _pc!.onIceCandidate = (candidate) {
        if (candidate.candidate == null || !_signalSubscribed) return;
        _sendSignal({
          'type': 'candidate',
          'from': _uid,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      final subscribed = Completer<void>();
      _signal = db.channel(
        'zameel-meet:${widget.roomId ?? 'room'}',
        opts: const RealtimeChannelConfig(ack: true),
      );
      _signal!
          .onBroadcast(
            event: 'signal',
            callback: (payload) => _handleSignal(
              _unwrapBroadcastPayload(Map<String, dynamic>.from(payload)),
            ),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'call_signals',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: widget.roomId ?? 'room',
            ),
            callback: (payload) {
              final row = Map<String, dynamic>.from(payload.newRecord);
              _handleSignal(Map<String, dynamic>.from(row['payload'] as Map? ?? const {}));
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'direct_call_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: widget.roomId ?? 'room',
            ),
            callback: (payload) {
              final row = Map<String, dynamic>.from(payload.newRecord);
              if (row['status'] == 'ended' && mounted) {
                Navigator.of(context).maybePop();
              }
            },
          )
          .onBroadcast(
            event: 'chat',
            callback: (payload) => _onChatSignal(
              _unwrapBroadcastPayload(Map<String, dynamic>.from(payload)),
            ),
          )
          .subscribe((status, error) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              _signalSubscribed = true;
              if (!subscribed.isCompleted) subscribed.complete();
            }
          });

      await subscribed.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw Exception('Realtime signaling subscription timed out'),
      );

      await _replayPersistedSignals();
      _startSignalPolling();

      // Because signaling is persisted in call_signals, the caller no longer
      // needs to wait for a fragile one-shot `ready` event. The callee can join
      // later and replay the stored offer. `ready` is still retained as an
      // acceleration/retry hint.
      if (_initiator) {
        await _sendOffer();
      } else {
        await _markCallAnswered();
        await _announceReady();
        _readyTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          if (!_remoteDescriptionSet && !_connected) {
            _announceReady();
          }
        });
      }

      _connectionWatchdog = Timer(const Duration(seconds: 18), () async {
        if (!_connected && mounted) {
          debugPrint('Zameel WebRTC watchdog: connection=$_connectionStateLabel ice=$_iceStateLabel room=${widget.roomId}');
          await _replayPersistedSignals();
          if (_initiator) {
            await _restartIce();
            await _sendOffer(allowResend: true);
          } else {
            await _announceReady();
          }
        }
      });

      if (mounted) setState(() => _starting = false);
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

  Map<String, dynamic> _unwrapBroadcastPayload(
    Map<String, dynamic> envelope,
  ) {
    final nested = envelope['payload'];
    if (nested is Map<String, dynamic>) return nested;
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return envelope;
  }

  void _markConnected() {
    _readyTimer?.cancel();
    _offerRetryTimer?.cancel();
    _signalPollTimer?.cancel();
    _connectionWatchdog?.cancel();
    if (mounted && !_connected) {
      setState(() => _connected = true);
    }
  }

  Future<void> _sendSignal(Map<String, dynamic> payload) async {
    final signal = _signal;
    final roomId = widget.roomId;
    if (!_signalSubscribed || signal == null || roomId == null || roomId.isEmpty) return;
    final message = Map<String, dynamic>.from(payload);
    message['signal_id'] ??= '${_uid ?? 'user'}:${DateTime.now().microsecondsSinceEpoch}';
    // Supabase's broadcast encoder may mutate the Map passed to it by wrapping
    // it as {type: broadcast, event: ..., payload: ...}. Persist immutable
    // copies first; otherwise the database receives type=broadcast instead of
    // offer/answer/candidate and the remote peer silently ignores every signal.
    try {
      await Supabase.instance.client.rpc('send_call_signal', params: {
        'target_room_id': roomId,
        'signal_payload': Map<String, dynamic>.from(message),
      });
    } catch (e) {
      debugPrint('Meeting persisted signal send error: $e');
    }
    // A second durable mailbox is stored on direct_call_sessions itself.  The
    // session row is already proven to reach both devices (synchronised hangup),
    // so this path avoids losing SDP when Realtime/table replication is delayed.
    try {
      final sequence = await Supabase.instance.client.rpc(
        'publish_call_signal_v2',
        params: {
          'target_room_id': roomId,
          'signal_payload': Map<String, dynamic>.from(message),
        },
      );
      debugPrint('Zameel WebRTC mailbox sent type=${message['type']} seq=$sequence');
    } catch (e) {
      debugPrint('Zameel WebRTC mailbox send error: $e');
    }
    try {
      await signal.sendBroadcastMessage(
        event: 'signal',
        payload: Map<String, dynamic>.from(message),
      );
    } catch (e) {
      debugPrint('Meeting broadcast signal send error: $e');
    }
  }

  Future<void> _replayPersistedSignals() async {
    final roomId = widget.roomId;
    if (roomId == null || roomId.isEmpty) return;
    try {
      final response = await Supabase.instance.client.rpc(
        'get_call_signals',
        params: {'target_room_id': roomId, 'after_signal_id': _lastSignalRowId},
      );
      final rows = List<Map<String, dynamic>>.from(response as List? ?? const []);
      for (final row in rows) {
        final rowId = (row['signal_id'] as num?)?.toInt() ?? 0;
        if (rowId > _lastSignalRowId) _lastSignalRowId = rowId;
        final raw = row['payload'];
        if (raw is Map) {
          await _handleSignal(Map<String, dynamic>.from(raw));
        }
      }
    } catch (e) {
      debugPrint('Meeting signal replay error: $e');
    }
    await _replaySessionMailbox();
  }

  Future<void> _replaySessionMailbox() async {
    final roomId = widget.roomId;
    if (roomId == null || roomId.isEmpty) return;
    try {
      final response = await Supabase.instance.client.rpc(
        'get_call_signals_v2',
        params: {'target_room_id': roomId},
      );
      if (response is! List || response.isEmpty || response.first is! Map) return;
      final row = Map<String, dynamic>.from(response.first as Map);
      final rawSignals = row['signals'];
      if (rawSignals is! List) return;
      var handled = 0;
      for (final raw in rawSignals) {
        if (raw is! Map) continue;
        final message = Map<String, dynamic>.from(raw);
        final before = _handledSignalIds.length;
        await _handleSignal(message);
        if (_handledSignalIds.length > before) handled++;
      }
      if (handled > 0) {
        debugPrint('Zameel WebRTC mailbox replay handled=$handled total=${rawSignals.length}');
      }
    } catch (e) {
      debugPrint('Zameel WebRTC mailbox replay error: $e');
    }
  }

  void _startSignalPolling() {
    _signalPollTimer?.cancel();
    _signalPollTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!_connected) {
        _replayPersistedSignals();
      }
    });
  }

  Future<void> _markCallAnswered() async {
    final roomId = widget.roomId;
    if (roomId == null || roomId.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('direct_call_sessions')
          .update({
            'status': 'active',
            'answered_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('room_id', roomId)
          .neq('status', 'ended');
    } catch (e) {
      debugPrint('Zameel WebRTC mark answered error: $e');
    }
  }

  Future<void> _restartIce() async {
    final pc = _pc;
    if (pc == null || !_signalSubscribed) return;
    try {
      await pc.restartIce();
      if (_initiator) {
        final offer = await pc.createOffer({'iceRestart': true});
        _beginIceGatheringWait();
        await pc.setLocalDescription(offer);
        final completeOffer = await _completeLocalDescription();
        _lastOfferSdp = completeOffer.sdp;
        await _sendSignal({
          'type': 'offer',
          'from': _uid,
          'sdp': completeOffer.sdp,
          'ice_restart': true,
        });
        _offerSent = true;
      }
    } catch (e) {
      debugPrint('Zameel WebRTC ICE restart error: $e');
    }
  }

  Future<void> _announceReady() async {
    await _sendSignal({'type': 'ready', 'from': _uid});
  }

  void _beginIceGatheringWait() {
    _iceGatheringCompleter = Completer<void>();
  }

  Future<RTCSessionDescription> _completeLocalDescription() async {
    final pc = _pc;
    if (pc == null) throw StateError('Peer connection is not ready');
    final completer = _iceGatheringCompleter ?? Completer<void>();
    _iceGatheringCompleter = completer;
    final current = await pc.getLocalDescription();
    if (current == null) throw StateError('Local SDP is missing');
    try {
      await completer.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('Zameel WebRTC: ICE gathering timeout; sending gathered SDP');
    } finally {
      if (identical(_iceGatheringCompleter, completer)) _iceGatheringCompleter = null;
    }
    return await pc.getLocalDescription() ?? current;
  }

  Future<void> _sendOffer({bool allowResend = false}) async {
    final pc = _pc;
    if (!_initiator || pc == null || !_signalSubscribed || _makingOffer) return;

    if (_offerSent) {
      if (allowResend && !_remoteDescriptionSet && _lastOfferSdp != null) {
        await _sendSignal({
          'type': 'offer',
          'from': _uid,
          'sdp': _lastOfferSdp,
        });
      }
      return;
    }

    _makingOffer = true;
    try {
      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      _beginIceGatheringWait();
      await pc.setLocalDescription(offer);
      final completeOffer = await _completeLocalDescription();
      _lastOfferSdp = completeOffer.sdp;
      await _sendSignal({
        'type': 'offer',
        'from': _uid,
        'sdp': completeOffer.sdp,
      });
      _offerSent = true;
      _offerRetryTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
        if (!_remoteDescriptionSet && !_connected) {
          _sendOffer(allowResend: true);
        }
      });
    } finally {
      _makingOffer = false;
    }
  }

  Future<void> _setRemoteDescription(
    RTCSessionDescription description,
  ) async {
    final pc = _pc;
    if (pc == null) return;
    await pc.setRemoteDescription(description);
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
  }

  Future<void> _flushPendingCandidates() async {
    final pc = _pc;
    if (pc == null || !_remoteDescriptionSet) return;
    final queued = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in queued) {
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        debugPrint('Queued ICE candidate error: $e');
      }
    }
  }

  Future<void> _handleSignal(Map<String, dynamic> msg) async {
    // Accept a Supabase transport envelope defensively. Older builds persisted
    // this wrapper in the mailbox, and different realtime_client versions can
    // expose either the inner payload or the complete broadcast object.
    if (msg['type'] == 'broadcast' && msg['payload'] is Map) {
      await _handleSignal(
        Map<String, dynamic>.from(msg['payload'] as Map),
      );
      return;
    }
    final signalId = msg['signal_id']?.toString();
    if (signalId != null && signalId.isNotEmpty && !_handledSignalIds.add(signalId)) return;
    if (msg['from']?.toString() == _uid) return;
    final pc = _pc;
    if (pc == null) return;

    try {
      switch (msg['type']) {
        case 'ready':
          if (_initiator && !_remoteDescriptionSet) {
            await _sendOffer(allowResend: true);
          }
          break;
        case 'offer':
          _readyTimer?.cancel();
          final iceRestart = msg['ice_restart'] == true;
          // A normal duplicate offer means our previous answer was probably
          // missed, so resend it. An ICE-restart offer is a real renegotiation
          // and must replace the current remote description.
          if (_remoteDescriptionSet && !iceRestart) {
            if (_lastAnswerSdp != null) {
              await _sendSignal({
                'type': 'answer',
                'from': _uid,
                'sdp': _lastAnswerSdp,
              });
            }
            return;
          }
          await _setRemoteDescription(
            RTCSessionDescription(msg['sdp']?.toString() ?? '', 'offer'),
          );
          final answer = await pc.createAnswer({
            'offerToReceiveAudio': true,
            'offerToReceiveVideo': true,
          });
          _beginIceGatheringWait();
          await pc.setLocalDescription(answer);
          final completeAnswer = await _completeLocalDescription();
          _lastAnswerSdp = completeAnswer.sdp;
          await _sendSignal({
            'type': 'answer',
            'from': _uid,
            'sdp': completeAnswer.sdp,
            if (iceRestart) 'ice_restart': true,
          });
          break;
        case 'answer':
          _offerRetryTimer?.cancel();
          final iceRestart = msg['ice_restart'] == true;
          if (_remoteDescriptionSet && !iceRestart) return;
          await _setRemoteDescription(
            RTCSessionDescription(msg['sdp']?.toString() ?? '', 'answer'),
          );
          break;
        case 'candidate':
          final c = msg['candidate']?.toString();
          if (c == null || c.isEmpty) return;
          final candidate = RTCIceCandidate(
            c,
            msg['sdpMid']?.toString(),
            (msg['sdpMLineIndex'] as num?)?.toInt(),
          );
          if (_remoteDescriptionSet) {
            await pc.addCandidate(candidate);
          } else {
            _pendingRemoteCandidates.add(candidate);
          }
          break;
        case 'bye':
          _readyTimer?.cancel();
          _offerRetryTimer?.cancel();
          if (mounted) {
            Navigator.of(context).maybePop();
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
      await _sendSignal({'type': 'bye', 'from': _uid});
      final roomId = widget.roomId;
      if (roomId != null && roomId.isNotEmpty) {
        await Supabase.instance.client
            .from('direct_call_sessions')
            .update({'status': 'ended', 'ended_at': DateTime.now().toUtc().toIso8601String()})
            .eq('room_id', roomId);
      }
      _readyTimer?.cancel();
      _offerRetryTimer?.cancel();
      _signalPollTimer?.cancel();
      _connectionWatchdog?.cancel();
      for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        await track.stop();
      }
      await _localStream?.dispose();
      await _remoteStream?.dispose();
      await _pc?.close();
      _signalSubscribed = false;
      await _signal?.unsubscribe();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _offerRetryTimer?.cancel();
    _signalPollTimer?.cancel();
    _connectionWatchdog?.cancel();
    _signalSubscribed = false;
    _signal?.unsubscribe();
    _pc?.close();
    _localStream?.dispose();
    _remoteStream?.dispose();
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
                        if (widget.startWithVideo)
                          _control(
                            icon: _videoOn
                                ? Icons.videocam_rounded
                                : Icons.videocam_off_rounded,
                            onTap: _toggleVideo,
                          ),
                        if (widget.startWithVideo)
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
                        _control(
                          icon: Icons.call_end_rounded,
                          onTap: _hangUp,
                          backgroundColor: Colors.redAccent,
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
    Color? backgroundColor,
  }) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: backgroundColor ?? AppTheme.primary,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
