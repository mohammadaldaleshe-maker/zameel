import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/call_invitation_guard.dart';
import '../../services/screen_awake_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final String roomId;
  final String callerName;
  final String? callerImage;
  final bool video;

  const IncomingCallScreen({
    super.key,
    required this.roomId,
    required this.callerName,
    this.callerImage,
    required this.video,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _sessionTimer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ScreenAwakeService.enterPersistent();
    _verifySession();
    _sessionTimer = Timer.periodic(
      const Duration(seconds: 5), (_) => _verifySession(),
    );
  }

  Future<void> _verifySession() async {
    if (_busy || !mounted) return;
    if (!await CallInvitationGuard.isRinging(widget.roomId) && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    ScreenAwakeService.exitPersistent();
    super.dispose();
  }

  Future<void> _respond(bool accepted) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (accepted && !await CallInvitationGuard.isRinging(widget.roomId)) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    if (mounted) Navigator.of(context).pop(accepted);
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF122040);
    const teal = Color(0xFF33C6B2);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: navy,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF122040), Color(0xFF162E58), Color(0xFF101D38)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                children: [
                  const SizedBox(height: 36),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Image.asset('assets/branding/zameel_mark_white.png',
                        width: 32, height: 32,
                        errorBuilder: (_, __, ___) => const Icon(Icons.hub_rounded, color: Colors.white)),
                    const SizedBox(width: 10),
                    const Text('Zameel', style: TextStyle(color: Colors.white,
                        fontSize: 23, fontWeight: FontWeight.w800)),
                  ]),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        border: Border.all(color: teal.withOpacity(.7), width: 2)),
                    child: CircleAvatar(
                      radius: 66,
                      backgroundColor: Colors.white12,
                      backgroundImage: widget.callerImage?.isNotEmpty == true
                          ? NetworkImage(widget.callerImage!) : null,
                      child: widget.callerImage?.isNotEmpty == true ? null
                          : const Icon(Icons.person_rounded, size: 72, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(widget.callerName, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(widget.video ? 'مكالمة فيديو واردة' : 'مكالمة صوتية واردة',
                      style: const TextStyle(color: Color(0xFFC2D5E6), fontSize: 17)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white10,
                        borderRadius: BorderRadius.circular(24)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(widget.video ? Icons.videocam_rounded : Icons.call_rounded,
                          color: teal, size: 18),
                      const SizedBox(width: 7),
                      const Text('مكالمة آمنة عبر زميل',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                    ]),
                  ),
                  const Spacer(flex: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _callButton(icon: Icons.call_end_rounded, label: 'رفض',
                        color: const Color(0xFFE84D64), onTap: () => _respond(false)),
                    _callButton(icon: widget.video ? Icons.videocam_rounded : Icons.call_rounded,
                        label: 'رد', color: const Color(0xFF19A884),
                        onTap: () => _respond(true)),
                  ]),
                  const SizedBox(height: 40),
                  const Text('تنتهي الدعوة تلقائيًا إذا أُلغيت المكالمة',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _callButton({required IconData icon, required String label,
      required Color color, required VoidCallback onTap}) {
    return Column(children: [
      Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 6,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _busy ? null : onTap,
          child: SizedBox(width: 76, height: 76,
              child: Icon(icon, color: Colors.white, size: 36)),
        ),
      ),
      const SizedBox(height: 12),
      Text(label, style: const TextStyle(color: Colors.white,
          fontSize: 16, fontWeight: FontWeight.w700)),
    ]);
  }
}
