import 'package:flutter/material.dart';

/// Visual building blocks for the in-call screen. They only draw; all call
/// signalling and media logic stays in `meet_screen.dart`.

/// Soft backdrop for calls: the caller's photo blurred and darkened when one
/// exists, otherwise a deep gradient in Zameel's colours.
class CallBackdrop171 extends StatelessWidget {
  const CallBackdrop171({super.key, this.imageUrl, required this.accent});

  final String? imageUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;
    return RepaintBoundary(
        child: Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(accent.withValues(alpha: .55),
                    const Color(0xFF0B1020)),
                const Color(0xFF0B1020),
                Color.alphaBlend(accent.withValues(alpha: .25),
                    const Color(0xFF05070F)),
              ],
            ),
          ),
        ),
        if (hasImage)
          // A tiny decode scaled up smoothly looks blurred but costs almost
          // nothing, unlike a live full-screen blur filter.
          Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: 40,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: hasImage ? .55 : .0),
          ),
        ),
      ],
    ));
  }
}

/// Large round avatar with soft rings that pulse outward while the call is
/// ringing or connecting.
class CallPulseAvatar171 extends StatefulWidget {
  const CallPulseAvatar171({
    super.key,
    required this.name,
    required this.accent,
    this.imageUrl,
    this.pulsing = true,
    this.size = 132,
  });

  final String name;
  final String? imageUrl;
  final Color accent;
  final bool pulsing;
  final double size;

  @override
  State<CallPulseAvatar171> createState() => _CallPulseAvatar171State();
}

class _CallPulseAvatar171State extends State<CallPulseAvatar171>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _controller.repeat();
  }

  @override
  void didUpdateWidget(CallPulseAvatar171 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _initial {
    final text = widget.name.trim();
    if (text.isEmpty) return 'Z';
    return String.fromCharCode(text.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final outer = size * 1.9;
    final url = widget.imageUrl;
    final hasImage = url != null && url.isNotEmpty;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
              child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return CustomPaint(
                size: Size(outer, outer),
                painter: _PulsePainter171(
                  progress: _controller.value,
                  color: widget.accent,
                  baseRadius: size / 2,
                  maxRadius: outer / 2,
                  active: widget.pulsing,
                ),
              );
            },
          )),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 3),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: .45),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [widget.accent, const Color(0xFF1B2250)],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: hasImage
                ? Image.network(
                    url,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => _letter(size),
                  )
                : _letter(size),
          ),
        ],
      ),
    );
  }

  Widget _letter(double size) => Text(
        _initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .42,
          fontWeight: FontWeight.w900,
        ),
      );
}

class _PulsePainter171 extends CustomPainter {
  _PulsePainter171({
    required this.progress,
    required this.color,
    required this.baseRadius,
    required this.maxRadius,
    required this.active,
  });

  final double progress;
  final Color color;
  final double baseRadius;
  final double maxRadius;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Three rings, evenly spaced in time, each growing and fading out.
    for (var i = 0; i < 3; i++) {
      final t = active ? (progress + i / 3) % 1.0 : 0.0;
      final radius = baseRadius + (maxRadius - baseRadius) * t;
      final alpha = active ? (1 - t) * .32 : .12;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = color.withValues(alpha: alpha);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter171 old) =>
      old.progress != progress ||
      old.active != active ||
      old.color != color ||
      old.baseRadius != baseRadius ||
      old.maxRadius != maxRadius;
}

/// Round call button with a clear on/off look and a smooth state change.
class CallControlButton171 extends StatelessWidget {
  const CallControlButton171({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.danger = false,
    this.size = 58,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Highlighted state (for example "muted" or "sharing").
  final bool active;
  final bool danger;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color fill = danger
        ? const Color(0xFFE5383B)
        : (active ? Colors.white : Colors.white.withValues(alpha: .16));
    final Color glyph = danger
        ? Colors.white
        : (active ? const Color(0xFF0B1020) : Colors.white);
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                boxShadow: danger
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE5383B).withValues(alpha: .5),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : const [],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(icon, key: ValueKey(icon), color: glyph, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: size + 14,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small rounded self-view that can be dragged anywhere on the screen and
/// tapped to swap with the main picture.
class CallDraggablePip171 extends StatefulWidget {
  const CallDraggablePip171({
    super.key,
    required this.child,
    required this.onTap,
    this.width = 112,
    this.height = 160,
    this.topInset = 56,
    this.bottomInset = 150,
  });

  final Widget child;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double topInset;
  final double bottomInset;

  @override
  State<CallDraggablePip171> createState() => _CallDraggablePip171State();
}

class _CallDraggablePip171State extends State<CallDraggablePip171> {
  // Offset from the top-end corner; null until the first drag.
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      double bound(double v, double lo, double hi) =>
          v < lo ? lo : (v > hi ? hi : v);
      final maxX = bound(constraints.maxWidth - widget.width, 0, 4000);
      final maxY = bound(
          constraints.maxHeight - widget.height - widget.bottomInset,
          widget.topInset,
          4000);
      final isRtl = Directionality.of(context) == TextDirection.rtl;
      final start = _position ??
          Offset(isRtl ? 16.0 : bound(maxX - 16, 0, maxX), widget.topInset);
      final dx = bound(start.dx, 0, maxX);
      final dy = bound(start.dy, widget.topInset, maxY);
      return Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 60),
            left: dx,
            top: dy,
            width: widget.width,
            height: widget.height,
            child: GestureDetector(
              onTap: widget.onTap,
              onPanUpdate: (details) {
                setState(() {
                  _position = Offset(
                    bound(dx + details.delta.dx, 0, maxX),
                    bound(dy + details.delta.dy, widget.topInset, maxY),
                  );
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white38, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 14),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.child,
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Small pill shown on top of the call, e.g. "reconnecting".
class CallStatusPill171 extends StatelessWidget {
  const CallStatusPill171({
    super.key,
    required this.text,
    this.icon,
    this.warning = false,
  });

  final String text;
  final IconData? icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: warning
            ? const Color(0xFFFFA000).withValues(alpha: .9)
            : Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
