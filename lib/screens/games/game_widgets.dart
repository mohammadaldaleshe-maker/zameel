import 'package:flutter/material.dart';

import '../../games/cards.dart';
import '../../theme/app_theme.dart';

const Color _cardRed = Color(0xFFD32F2F);
const Color _cardBlack = Color(0xFF212121);

Color suitColor(Suit suit) => isRedSuit(suit) ? _cardRed : _cardBlack;

// A playing card drawn with plain widgets.
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
    Widget face;
    if (faceDown || current == null) {
      face = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Center(
          child: Icon(Icons.auto_awesome, color: Colors.white54, size: 16),
        ),
      );
    } else {
      final color = suitColor(current.suit);
      face = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: highlight ? AppTheme.primary : const Color(0xFFB0B4C0),
            width: highlight ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              rankLabel(current.rank),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: color,
                fontSize: width * 0.36,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            Text(
              suitSymbol(current.suit),
              style: TextStyle(
                color: color,
                fontSize: width * 0.42,
                height: 1.0,
              ),
            ),
          ],
        ),
      );
    }
    if (!enabled) face = Opacity(opacity: 0.45, child: face);
    if (onTap != null && enabled) {
      return GestureDetector(onTap: onTap, child: face);
    }
    return face;
  }
}

String gameSeatName(int seat, bool ar, {bool teams = false}) {
  if (seat == 0) return ar ? 'أنت' : 'You';
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

// Small rounded label used for seats and scores.
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
    final scheme = Theme.of(context).colorScheme;
    final sub = subtitle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : scheme.onSurface,
            ),
          ),
          if (sub != null)
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                color: active ? Colors.white70 : scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
