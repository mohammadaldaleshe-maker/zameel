import 'dart:math';

import 'package:flutter/material.dart';

import '../../games/cards.dart';
import '../../theme/app_theme.dart';
import 'bot_personas.dart';
import 'game_kit.dart';

const Color _cardRed = Color(0xFFD32F2F);
const Color _cardBlack = Color(0xFF1E2033);

Color suitColor(Suit suit) => isRedSuit(suit) ? _cardRed : _cardBlack;

// A playing card painted with plain widgets: ivory face, corner indices and a
// large centre suit. Face down it shows the Zameel emblem pattern.
class GameCardView extends StatelessWidget {
  const GameCardView({
    super.key,
    this.card,
    this.faceDown = false,
    this.width = 46,
    this.enabled = true,
    this.highlight = false,
    this.onTap,
  });

  final PlayingCard? card;
  final bool faceDown;
  final double width;
  final bool enabled;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.42;
    final current = card;
    final radius = BorderRadius.circular(width * 0.15);
    Widget face;
    if (faceDown || current == null) {
      face = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppTheme.primary, AppTheme.primaryDark],
          ),
          borderRadius: radius,
          border: Border.all(color: Colors.white, width: width * 0.045),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            painter: _CardBackPainter(),
            child: Center(
              child: Container(
                width: width * 0.46,
                height: width * 0.46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.7),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Z',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: width * 0.3,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      final color = suitColor(current.suit);
      final rank = rankLabel(current.rank);
      final symbol = suitSymbol(current.suit);
      final royal = current.rank >= 11 && current.rank <= 13;
      final index = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rank,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: color,
              fontSize: width * 0.34,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          Text(
            symbol,
            style: TextStyle(color: color, fontSize: width * 0.3, height: 1.0),
          ),
        ],
      );
      face = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Colors.white, Color(0xFFEFF1FA)],
          ),
          borderRadius: radius,
          border: Border.all(
            color: highlight ? kGameGold : const Color(0xFFC3C8DA),
            width: highlight ? 2.5 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: highlight
                  ? kGameGold.withOpacity(0.55)
                  : const Color(0x55000000),
              blurRadius: highlight ? 10 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: width * 0.07,
              top: width * 0.05,
              child: index,
            ),
            Positioned(
              right: width * 0.07,
              bottom: width * 0.05,
              child: Transform.rotate(angle: pi, child: index),
            ),
            Center(
              child: royal
                  ? Container(
                      width: width * 0.5,
                      height: width * 0.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.10),
                        border: Border.all(color: color.withOpacity(0.55)),
                      ),
                      child: Center(
                        child: Text(
                          symbol,
                          style: TextStyle(
                            color: color,
                            fontSize: width * 0.34,
                            height: 1.0,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      symbol,
                      style: TextStyle(
                        color: color,
                        fontSize: width * 0.5,
                        height: 1.0,
                      ),
                    ),
            ),
          ],
        ),
      );
    }
    if (!enabled) face = Opacity(opacity: 0.42, child: face);
    if (onTap != null && enabled) {
      return GestureDetector(onTap: onTap, child: face);
    }
    return face;
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final step = size.width / 4;
    for (var i = -8; i < 16; i++) {
      final x = i * step;
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// A row (or column) of overlapping face-down cards for an opponent's hand.
class CardBackFan extends StatelessWidget {
  const CardBackFan({
    super.key,
    required this.count,
    this.width = 28,
    this.vertical = false,
  });

  final int count;
  final double width;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return SizedBox(width: width, height: width);
    final step = width * 0.3;
    final cardHeight = width * 1.42;
    final length = width + step * (count - 1);
    final children = <Widget>[];
    for (var i = 0; i < count; i++) {
      final back = GameCardView(faceDown: true, width: width);
      if (vertical) {
        children.add(Positioned(
          top: step * i,
          left: 0,
          child: RotatedBox(quarterTurns: 1, child: back),
        ));
      } else {
        children.add(Positioned(left: step * i, top: 0, child: back));
      }
    }
    return SizedBox(
      width: vertical ? cardHeight : length,
      height: vertical ? length : cardHeight,
      child: Stack(children: children),
    );
  }
}

// The player's own hand, fanned along a gentle arc. Cards that can be played
// lift up; the others are dimmed.
class FannedHand extends StatelessWidget {
  const FannedHand({
    super.key,
    required this.cards,
    required this.canPlay,
    required this.legal,
    required this.onPlay,
  });

  final List<PlayingCard> cards;
  final bool canPlay;
  final List<PlayingCard> legal;
  final void Function(PlayingCard card) onPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width;
      final n = cards.length;
      final cardWidth = min(76.0, max(46.0, available / 5.0));
      final cardHeight = cardWidth * 1.42;
      final maxStep = cardWidth * 0.7;
      final step = n <= 1
          ? 0.0
          : min(maxStep, max(8.0, (available - cardWidth - 8) / (n - 1)));
      final total = cardWidth + step * (n <= 1 ? 0 : n - 1);
      final start = (available - total) / 2;
      final half = (n - 1) / 2;
      final children = <Widget>[];
      for (var i = 0; i < n; i++) {
        final card = cards[i];
        final t = half <= 0 ? 0.0 : (i - half) / half;
        final playable = canPlay && legal.contains(card);
        final lift = playable ? -16.0 : 0.0;
        children.add(AnimatedPositioned(
          key: ValueKey<String>('hand_${card.suit.index}_${card.rank}'),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          left: start + step * i,
          top: 18 + t * t * 12 + lift,
          child: Transform.rotate(
            angle: t * 0.17,
            alignment: Alignment.bottomCenter,
            child: GameCardView(
              card: card,
              width: cardWidth,
              enabled: !canPlay || playable,
              highlight: playable,
              onTap: playable ? () => onPlay(card) : null,
            ),
          ),
        ));
      }
      return Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: cardHeight + 36,
          width: double.infinity,
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      );
    });
  }
}

// Felt style table: deep indigo cloth with a teal rim and a faint emblem.
class GameFeltTable extends StatelessWidget {
  const GameFeltTable({super.key, required this.child, this.height = 330});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2.4),
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: <Color>[Color(0xFF3550D8), Color(0xFF1B2475), Color(0xFF111552)],
        ),
        border: Border.all(color: kGameTeal.withOpacity(0.75), width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2.4),
        child: CustomPaint(
          painter: _FeltPainter(),
          child: child,
        ),
      ),
    );
  }
}

class _FeltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14, 14, size.width - 28, size.height - 28),
        Radius.circular(size.height / 2.9),
      ),
      ring,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: 'Z',
        style: TextStyle(
          color: Colors.white.withOpacity(0.07),
          fontSize: size.height * 0.46,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Cards thrown into the middle of the table: each one flies in from the seat
// that played it and settles with a small random-looking tilt.
class TrickArea extends StatelessWidget {
  const TrickArea({
    super.key,
    required this.plays,
    this.cardWidth = 44,
    this.size = 150,
  });

  final List<TrickPlay> plays;
  final double cardWidth;
  final double size;

  static const List<Offset> _from = <Offset>[
    Offset(0, 190),
    Offset(-170, 0),
    Offset(0, -190),
    Offset(170, 0),
  ];
  static const List<double> _tilt = <double>[0.05, -0.16, 0.1, 0.2];
  static const List<Alignment> _slot = <Alignment>[
    Alignment(0, 0.95),
    Alignment(-0.95, 0),
    Alignment(0, -0.95),
    Alignment(0.95, 0),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          for (final play in plays)
            Align(
              key: ValueKey<String>('trick_${play.seat}_${play.card}'),
              alignment: _slot[play.seat % 4],
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) {
                  final from = _from[play.seat % 4];
                  return Opacity(
                    opacity: v.clamp(0.0, 1.0).toDouble(),
                    child: Transform.translate(
                      offset: Offset(from.dx * (1 - v), from.dy * (1 - v)),
                      child: Transform.rotate(
                        angle: _tilt[play.seat % 4] + (1 - v) * 2.4,
                        child: child,
                      ),
                    ),
                  );
                },
                child: GameCardView(card: play.card, width: cardWidth),
              ),
            ),
        ],
      ),
    );
  }
}

// Name plate for a seat around the table.
class GameSeatBadge extends StatelessWidget {
  const GameSeatBadge({
    super.key,
    required this.name,
    required this.subtitle,
    required this.active,
    this.seat = 0,
    this.compact = false,
  });

  final String name;
  final String subtitle;
  final bool active;
  final int seat;
  final bool compact;

  static const List<Color> _colors = <Color>[
    kGameTeal,
    Color(0xFFFF8A5B),
    Color(0xFFB583FF),
    Color(0xFFFF5C8A),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[seat % 4];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(active ? 0.55 : 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? color : Colors.white.withOpacity(0.2),
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? <BoxShadow>[BoxShadow(color: color.withOpacity(0.6), blurRadius: 14)]
            : const <BoxShadow>[],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsetsDirectional.only(end: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: seat == 0 ? color : null,
              ),
              child: seat == 0
                  ? const Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: Colors.white,
                    )
                  : (BotCast.current?.at(seat) == null
                      ? const Icon(
                          Icons.smart_toy_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : BotAvatar(
                          persona: BotCast.current!.at(seat)!,
                          size: 30,
                        )),
            ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    height: 1.15,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 10.5,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String gameSeatName(int seat, bool ar, {bool teams = false}) {
  if (seat == 0) return ar ? 'أنت' : 'You';
  final persona = BotCast.current?.at(seat);
  if (persona != null) {
    final base = persona.name(ar);
    if (teams && seat == 2) {
      final role = ar
          ? (persona.female ? 'شريكتك' : 'شريكك')
          : 'partner';
      return '$base ($role)';
    }
    return base;
  }
  if (teams) {
    if (seat == 2) return ar ? 'شريكك' : 'Partner';
    if (seat == 1) return ar ? 'الخصم ١' : 'Opponent 1';
    return ar ? 'الخصم ٢' : 'Opponent 2';
  }
  if (seat == 1) return ar ? 'لاعب ٢' : 'Player 2';
  if (seat == 2) return ar ? 'لاعب ٣' : 'Player 3';
  return ar ? 'لاعب ٤' : 'Player 4';
}

Future<bool> confirmLeaveGame(BuildContext context, bool ar) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ar ? 'الخروج من اللعبة؟' : 'Leave the game?'),
      content: Text(ar
          ? 'سيضيع تقدمك في هذه اللعبة.'
          : 'Your progress in this game will be lost.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ar ? 'متابعة اللعب' : 'Keep playing'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ar ? 'خروج' : 'Leave'),
        ),
      ],
    ),
  );
  return result == true;
}

Future<bool> confirmNewGame(BuildContext context, bool ar) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ar ? 'لعبة جديدة؟' : 'Start a new game?'),
      content: Text(ar
          ? 'ستبدأ لعبة جديدة وتضيع اللعبة الحالية.'
          : 'The current game will be lost.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ar ? 'إلغاء' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ar ? 'ابدأ' : 'Start'),
        ),
      ],
    ),
  );
  return result == true;
}

// Rounded label used for scores on the dark game background.
class GamePill extends StatelessWidget {
  const GamePill({
    super.key,
    required this.text,
    this.active = false,
    this.subtitle,
  });

  final String text;
  final bool active;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? kGameTeal.withOpacity(0.3) : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? kGameTeal : Colors.white.withOpacity(0.18),
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          if (sub != null)
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.75),
              ),
            ),
        ],
      ),
    );
  }
}
