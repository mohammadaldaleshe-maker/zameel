import 'dart:math';

import 'package:flutter/material.dart';

import '../../games/snakes_ladders.dart';
import '../../theme/app_theme.dart';
import 'bot_personas.dart';
import 'game_kit.dart';

// Snakes and ladders: against the phone or two players on one phone.
// Rules live in lib/games/snakes_ladders.dart.
class SnakesLaddersGameScreen extends StatefulWidget {
  const SnakesLaddersGameScreen({super.key, required this.isArabic});

  final bool isArabic;

  @override
  State<SnakesLaddersGameScreen> createState() =>
      _SnakesLaddersGameScreenState();
}

const List<Color> _tokenColors = <Color>[kGameTeal, Color(0xFFFF5C8A)];

class _SnakesLaddersGameScreenState extends State<SnakesLaddersGameScreen> {
  final Random _rng = Random();
  SnakesLaddersGame _game = SnakesLaddersGame();
  // Square each token is drawn on (it walks there step by step).
  List<int> _shown = <int>[0, 0];
  int _mode = 0;
  int _die = 1;
  bool _rolling = false;
  bool _busy = false;
  int _generation = 0;
  int _confetti = 0;
  SlMove? _last;

  late final BotPersona _bot = BotCast.draw(const <int>[1]).at(1)!;
  bool get _ar => widget.isArabic;
  String _t(String ar, String en) => _ar ? ar : en;

  String _name(int player) {
    if (_mode == 0) {
      return player == 0 ? _t('أنت', 'You') : _bot.name(_ar);
    }
    return player == 0 ? _t('اللاعب ١', 'Player 1') : _t('اللاعب ٢', 'Player 2');
  }

  Future<void> _pause(int milliseconds) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));

  bool get _phoneTurn => _mode == 0 && _game.turn == 1 && !_game.isOver;

  void _newGame() {
    _generation++;
    setState(() {
      _game = SnakesLaddersGame();
      _shown = <int>[0, 0];
      _die = 1;
      _rolling = false;
      _busy = false;
      _last = null;
    });
  }

  void _changeMode(int mode) {
    _mode = mode;
    _newGame();
  }

  void _maybePhoneTurn() {
    if (!mounted || !_phoneTurn || _busy) return;
    final token = _generation;
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || token != _generation) return;
      _doRoll();
    });
  }

  Future<void> _doRoll() async {
    if (_busy || _game.isOver) return;
    final token = _generation;
    _busy = true;
    setState(() => _rolling = true);
    for (var i = 0; i < 8; i++) {
      await _pause(70);
      if (!mounted || token != _generation) return;
      setState(() => _die = _rng.nextInt(6) + 1);
    }
    final roll = _rng.nextInt(6) + 1;
    final player = _game.turn;
    late SlMove move;
    setState(() {
      move = _game.play(roll);
      _die = roll;
      _rolling = false;
      _last = move;
    });
    if (move.landed != move.from) {
      for (var square = move.from + 1; square <= move.landed; square++) {
        setState(() => _shown[player] = square);
        await _pause(150);
        if (!mounted || token != _generation) return;
      }
      if (move.to != move.landed) {
        await _pause(250);
        if (!mounted || token != _generation) return;
        setState(() => _shown[player] = move.to);
        await _pause(650);
        if (!mounted || token != _generation) return;
      }
    } else {
      await _pause(300);
      if (!mounted || token != _generation) return;
    }
    _busy = false;
    if (move.won) {
      if (_mode == 1 || move.player == 0) setState(() => _confetti++);
      setState(() {});
      return;
    }
    setState(() {});
    _maybePhoneTurn();
  }

  String _status() {
    if (_game.isOver && !_busy) {
      return _mode == 0
          ? (_game.winner == 0
              ? _t('🏆 فزت!', '🏆 You win!')
              : _t('فاز الهاتف', 'The phone wins'))
          : _t('🏆 فاز ${_name(_game.winner)}', '🏆 ${_name(_game.winner)} wins');
    }
    final move = _last;
    if (_rolling) return _t('يتم الرمي...', 'Rolling...');
    if (move != null && !_busy) {
      final who = _name(move.player);
      String text;
      if (move.blocked) {
        text = _t('$who: تحتاج رمية مضبوطة للوصول إلى ١٠٠',
            '$who: needs an exact roll to reach 100');
      } else if (move.climbed) {
        text = _t('$who صعد السلم 🪜', '$who climbed a ladder 🪜');
      } else if (move.slid) {
        text = _t('$who لدغته حية 🐍', '$who hit a snake 🐍');
      } else {
        text = _t('$who: ${move.roll}', '$who rolled ${move.roll}');
      }
      if (move.extraTurn) {
        text = '$text — ${_t('رمية إضافية!', 'roll again!')}';
      }
      return text;
    }
    if (move == null) {
      return _t('الدور: ${_name(_game.turn)}', 'Turn: ${_name(_game.turn)}');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final over = _game.isOver && !_busy;
    final canRoll = !_busy && !over && !_phoneTurn;
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: GameScaffold(
        title: _t('الحية والسلم', 'Snakes & Ladders'),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [
                GameModeSwitch<int>(
                  choices: <GameChoice<int>>[
                    GameChoice<int>(0, _t('ضد الهاتف', 'vs Phone')),
                    GameChoice<int>(1, _t('لاعبان', 'Two players')),
                  ],
                  selected: _mode,
                  onChanged: _changeMode,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var p = 0; p < 2; p++)
                      GameScoreChip(
                        avatar: _mode == 0 && p == 1
                            ? BotAvatar(persona: _bot, size: 28)
                            : null,
                        label: _name(p),
                        value: _game.positions[p] == 0
                            ? '—'
                            : '${_game.positions[p]}',
                        accent: _tokenColors[p],
                        active: !over && _game.turn == p,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                GamePanel(
                  padding: const EdgeInsets.all(8),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(builder: (context, constraints) {
                        final side = constraints.maxWidth;
                        final cell = side / 10;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: CustomPaint(painter: _BoardPainter()),
                              ),
                            ),
                            for (var p = 0; p < 2; p++) _token(p, cell),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _DieView(value: _die, rolling: _rolling),
                    const SizedBox(width: 16),
                    Flexible(
                      child: GameBanner(
                        text: _status(),
                        size: 16,
                        color: over ? kGameGold : Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (over)
                  GameResultCard(
                    won: _mode == 1 || _game.winner == 0,
                    title: _status(),
                    child: GameButton(
                      onPressed: _newGame,
                      icon: Icons.refresh_rounded,
                      label: _t('لعبة جديدة', 'New game'),
                    ),
                  )
                else
                  Center(
                    child: GameButton(
                      onPressed: canRoll ? _doRoll : null,
                      icon: Icons.casino_rounded,
                      label: _mode == 1
                          ? _t('${_name(_game.turn)}: ارمِ النرد',
                              '${_name(_game.turn)}: roll')
                          : _t('ارمِ النرد', 'Roll the dice'),
                    ),
                  ),
              ],
            ),
            Positioned.fill(child: ConfettiBurst(trigger: _confetti)),
          ],
        ),
      ),
    );
  }

  Widget _token(int player, double cell) {
    final square = _shown[player];
    final cellPos = slCell(square <= 0 ? 1 : square);
    final other = _shown[1 - player];
    final shared = other == square;
    final size = cell * 0.5;
    final nudge = shared ? (player == 0 ? -cell * 0.16 : cell * 0.16) : 0.0;
    final left = cellPos.col * cell + (cell - size) / 2 + nudge;
    final top = (9 - cellPos.row) * cell + (cell - size) / 2 + (shared ? nudge : 0);
    final active = !_game.isOver && _game.turn == player;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      left: left,
      top: top,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: <Color>[Colors.white, _tokenColors[player]],
            stops: const <double>[0.0, 0.55],
          ),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _tokenColors[player].withOpacity(active ? 0.9 : 0.5),
              blurRadius: active ? 14 : 6,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${player + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _DieView extends StatelessWidget {
  const _DieView({required this.value, required this.rolling});

  final int value;
  final bool rolling;

  static const List<List<int>> _pips = <List<int>>[
    <int>[],
    <int>[4],
    <int>[0, 8],
    <int>[0, 4, 8],
    <int>[0, 2, 6, 8],
    <int>[0, 2, 4, 6, 8],
    <int>[0, 2, 3, 5, 6, 8],
  ];

  @override
  Widget build(BuildContext context) {
    final pips = _pips[value < 1 ? 1 : (value > 6 ? 6 : value)];
    return AnimatedRotation(
      turns: rolling ? (value.isEven ? 0.03 : -0.03) : 0,
      duration: const Duration(milliseconds: 80),
      child: Container(
        width: 66,
        height: 66,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Colors.white, Color(0xFFDDE2F5)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 9,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            for (var r = 0; r < 3; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < 3; c++)
                      Expanded(
                        child: Center(
                          child: pips.contains(r * 3 + c)
                              ? Container(
                                  width: 11,
                                  height: 11,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        AppTheme.primary,
                                        AppTheme.primaryDark,
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Paints the 10 x 10 board, the ladders and the snakes.
class _BoardPainter extends CustomPainter {
  static const List<Color> _snakeColors = <Color>[
    Color(0xFF2FD07A),
    Color(0xFFFF8A5B),
    Color(0xFFB583FF),
    Color(0xFFFF5C8A),
    Color(0xFF4CC9F0),
    Color(0xFFFFC857),
    Color(0xFF7BE0AD),
    Color(0xFFF08BD9),
  ];

  Offset _center(int square, double cell) {
    final c = slCell(square);
    return Offset((c.col + 0.5) * cell, (9 - c.row + 0.5) * cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 10;
    // Squares.
    for (var square = 1; square <= slBoardSize; square++) {
      final c = slCell(square);
      final rect = Rect.fromLTWH(c.col * cell, (9 - c.row) * cell, cell, cell);
      final dark = (c.col + c.row).isEven;
      Color color = dark ? const Color(0xFF2A3AA8) : const Color(0xFF3B2B94);
      if (square == 1) color = const Color(0xFF1C8A8A);
      if (square == slBoardSize) color = const Color(0xFFB8860B);
      canvas.drawRect(rect, Paint()..color = color);
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final label = square == slBoardSize
          ? '★'
          : (square == 1 ? 'GO' : '$square');
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.62),
            fontSize: cell * (square == slBoardSize ? 0.5 : 0.26),
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (square == slBoardSize) {
        painter.paint(
          canvas,
          Offset(rect.center.dx - painter.width / 2,
              rect.center.dy - painter.height / 2),
        );
      } else {
        painter.paint(canvas, Offset(rect.left + cell * 0.07, rect.top + cell * 0.04));
      }
    }
    // Ladders.
    slLadders.forEach((foot, top) {
      final a = _center(foot, cell);
      final b = _center(top, cell);
      final d = b - a;
      final len = d.distance;
      if (len == 0) return;
      final dir = d / len;
      final n = Offset(-dir.dy, dir.dx) * (cell * 0.15);
      final rail = Paint()
        ..color = kGameGold
        ..strokeWidth = cell * 0.075
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a + n, b + n, rail);
      canvas.drawLine(a - n, b - n, rail);
      final rung = Paint()
        ..color = kGameGold.withOpacity(0.9)
        ..strokeWidth = cell * 0.055
        ..strokeCap = StrokeCap.round;
      final rungs = (len / (cell * 0.42)).floor();
      for (var i = 1; i < rungs; i++) {
        final p = a + dir * (len * i / rungs);
        canvas.drawLine(p + n, p - n, rung);
      }
    });
    // Snakes.
    var index = 0;
    slSnakes.forEach((head, tail) {
      final color = _snakeColors[index % _snakeColors.length];
      index++;
      final a = _center(head, cell);
      final b = _center(tail, cell);
      final d = b - a;
      final len = d.distance;
      if (len == 0) return;
      final dir = d / len;
      final amp = min(cell * 0.95, len * 0.35);
      final n = Offset(-dir.dy, dir.dx) * amp;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(
          a.dx + d.dx * 0.33 + n.dx,
          a.dy + d.dy * 0.33 + n.dy,
          a.dx + d.dx * 0.66 - n.dx,
          a.dy + d.dy * 0.66 - n.dy,
          b.dx,
          b.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.24
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.07
          ..strokeCap = StrokeCap.round,
      );
      // Head with eyes.
      canvas.drawCircle(a, cell * 0.2, Paint()..color = color);
      canvas.drawCircle(
          a, cell * 0.2, Paint()..color = Colors.black.withOpacity(0.15));
      canvas.drawCircle(a, cell * 0.18, Paint()..color = color);
      final eyeOffset = Offset(-dir.dy, dir.dx) * (cell * 0.09);
      final eyeFront = dir * (-cell * 0.04);
      for (final sign in <double>[1, -1]) {
        final e = a + eyeOffset * sign + eyeFront;
        canvas.drawCircle(e, cell * 0.055, Paint()..color = Colors.white);
        canvas.drawCircle(e, cell * 0.025, Paint()..color = Colors.black);
      }
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
