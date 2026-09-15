import 'package:flutter/material.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String? callerImage;
  final bool video;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    this.callerImage,
    required this.video,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  double _drag = 0;

  void _finish(bool accepted) {
    if (mounted) Navigator.pop(context, accepted);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final limit = width * .24;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF151725),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 62,
                backgroundColor: Colors.white12,
                backgroundImage: widget.callerImage?.isNotEmpty == true
                    ? NetworkImage(widget.callerImage!)
                    : null,
                child: widget.callerImage?.isNotEmpty == true
                    ? null
                    : const Icon(Icons.person_rounded, size: 72, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Text(widget.callerName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(widget.video ? 'مكالمة فيديو واردة عبر زميل' : 'مكالمة صوتية واردة عبر زميل', style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
                  Column(children: [CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.call_end_rounded, color: Colors.white)), SizedBox(height: 7), Text('رفض', style: TextStyle(color: Colors.white70))]),
                  Column(children: [CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.call_rounded, color: Colors.white)), SizedBox(height: 7), Text('رد', style: TextStyle(color: Colors.white70))]),
                ]),
              ),
              const SizedBox(height: 24),
              Container(
                height: 82,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(42)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text('اسحب يمينًا للرد • يسارًا للرفض', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Transform.translate(
                      offset: Offset(_drag, 0),
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) => setState(() => _drag = (_drag + details.delta.dx).clamp(-limit, limit).toDouble()),
                        onHorizontalDragEnd: (_) {
                          if (_drag >= limit * .82) return _finish(true);
                          if (_drag <= -limit * .82) return _finish(false);
                          setState(() => _drag = 0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: _drag < 0 ? Colors.red : Colors.green, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)]),
                          child: Icon(_drag < 0 ? Icons.call_end_rounded : Icons.call_rounded, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
