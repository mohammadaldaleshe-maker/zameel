import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

// Shared look of every Zameel game: a deep indigo backdrop, glass panels,
// gradient buttons and a confetti burst. Nothing here knows any game rules.

const Color kGameDeep = Color(0xFF12143A);
const Color kGameMid = Color(0xFF281B78);
const Color kGameGold = Color(0xFFFFC857);
const Color kGameTeal = AppTheme.tertiary;

void gameTap() {
  HapticFeedback.selectionClick();
}

void gameWinBuzz() {
  HapticFeedback.mediumImpact();
}

// ------------------------------------------------------------ backdrop

class GameBackdrop extends StatelessWidget {
  const GameBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[kGameDeep, kGameMid, Color(0xFF1F2A8F)],
        ),
      ),
      child: CustomPaint(
        painter: _PatternPainter(),
        child: child,
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const step = 46.0;
    for (var y = -step; y < size.height + step; y += step) {
      for (var x = -step; x < size.width + step; x += step) {
        final shift = ((y / step).round() % 2 == 0) ? 0.0 : step / 2;
        final c = Offset(x + shift, y);
        final path = Path()
          ..moveTo(c.dx, c.dy - 9)
          ..lineTo(c.dx + 9, c.dy)
          ..lineTo(c.dx, c.dy + 9)
          ..lineTo(c.dx - 9, c.dy)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
    final glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          kGameTeal.withOpacity(0.20),
          kGameTeal.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.85, size.height * 0.08),
        radius: size.width * 0.7,
      ));
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGameDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 19,
          ),
        ),
        actions: actions,
      ),
      body: GameBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight),
            child: body,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- panels

class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: child,
    );
  }
}

class GameChoice<T> {
  const GameChoice(this.value, this.label);

  final T value;
  final String label;
}

// Pill shaped selector (replaces the plain Material segmented buttons).
class GameModeSwitch<T> extends StatelessWidget {
  const GameModeSwitch({
    super.key,
    required this.choices,
    required this.selected,
    required this.onChanged,
  });

  final List<GameChoice<T>> choices;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          for (final choice in choices)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  gameTap();
                  onChanged(choice.value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: choice.value == selected
                        ? const LinearGradient(
                            colors: <Color>[AppTheme.primary, kGameTeal],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    choice.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white
                          .withOpacity(choice.value == selected ? 1 : 0.7),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GameScoreChip extends StatelessWidget {
  const GameScoreChip({
    super.key,
    required this.label,
    required this.value,
    this.active = false,
    this.accent,
  });

  final String label;
  final String value;
  final bool active;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? kGameTeal;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      constraints: const BoxConstraints(minWidth: 82),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? color.withOpacity(0.28)
            : Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? color : Colors.white.withOpacity(0.16),
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? <BoxShadow>[
                BoxShadow(color: color.withOpacity(0.45), blurRadius: 14),
              ]
            : const <BoxShadow>[],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              value,
              key: ValueKey<String>(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    colors: <Color>[kGameTeal, AppTheme.primary],
                  )
                : null,
            color: primary ? null : Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(26),
            border: primary
                ? null
                : Border.all(color: Colors.white.withOpacity(0.3)),
            boxShadow: primary && enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: kGameTeal.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: enabled
                ? () {
                    gameTap();
                    onPressed!();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 21),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Big line of text that pops in when it changes (round result, turn, winner).
class GameBanner extends StatelessWidget {
  const GameBanner({
    super.key,
    required this.text,
    this.color = Colors.white,
    this.size = 20,
  });

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        text,
        key: ValueKey<String>(text),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
          shadows: const <Shadow>[
            Shadow(color: Colors.black38, blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ confetti

class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.trigger});

  // Every time this number changes to a value above zero the burst plays.
  final int trigger;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBit {
  const _ConfettiBit(
    this.x0,
    this.vx,
    this.vy,
    this.spin,
    this.color,
    this.size,
  );

  final double x0;
  final double vx;
  final double vy;
  final double spin;
  final Color color;
  final double size;
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  List<_ConfettiBit> _bits = const <_ConfettiBit>[];

  static const List<Color> _palette = <Color>[
    kGameGold,
    kGameTeal,
    Color(0xFFFF5C8A),
    Color(0xFF8E7BFF),
    Colors.white,
    Color(0xFF5BE37D),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.trigger > 0) _fire();
  }

  @override
  void didUpdateWidget(covariant ConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && widget.trigger > 0) _fire();
  }

  void _fire() {
    final rng = Random(widget.trigger * 7919 + 3);
    _bits = List<_ConfettiBit>.generate(80, (i) {
      return _ConfettiBit(
        0.5 + (rng.nextDouble() - 0.5) * 0.5,
        (rng.nextDouble() - 0.5) * 1.1,
        0.05 + rng.nextDouble() * 0.45,
        (rng.nextDouble() - 0.5) * 14,
        _palette[rng.nextInt(_palette.length)],
        5 + rng.nextDouble() * 6,
      );
    });
    gameWinBuzz();
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          if (t <= 0 || t >= 1) return const SizedBox.expand();
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_bits, t),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t);

  final List<_ConfettiBit> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
    for (final bit in bits) {
      final x = (bit.x0 + bit.vx * t) * size.width;
      final y = (-0.05 + bit.vy * t + 0.95 * t * t) * size.height;
      final paint = Paint()..color = bit.color.withOpacity(fade.clamp(0.0, 1.0).toDouble());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(bit.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: bit.size,
            height: bit.size * 0.55,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}

// Trophy / result card shown over the table when a match ends.
class GameResultCard extends StatelessWidget {
  const GameResultCard({
    super.key,
    required this.title,
    required this.won,
    required this.child,
  });

  final String title;
  final bool won;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: won
                ? const <Color>[Color(0xFF3A2A8F), Color(0xFF2056D8)]
                : const <Color>[Color(0xFF2A2E57), Color(0xFF1C2040)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: won ? kGameGold : Colors.white.withOpacity(0.2),
            width: won ? 2 : 1,
          ),
          boxShadow: won
              ? <BoxShadow>[
                  BoxShadow(color: kGameGold.withOpacity(0.35), blurRadius: 22),
                ]
              : const <BoxShadow>[],
        ),
        child: Column(
          children: [
            Icon(
              won ? Icons.emoji_events_rounded : Icons.sentiment_neutral_rounded,
              color: won ? kGameGold : Colors.white70,
              size: 46,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

// Soft glowing ring used behind active seats and tokens.
BoxDecoration gameGlow(Color color, {double radius = 18}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    boxShadow: <BoxShadow>[
      BoxShadow(color: color.withOpacity(0.55), blurRadius: 16),
    ],
  );
}
