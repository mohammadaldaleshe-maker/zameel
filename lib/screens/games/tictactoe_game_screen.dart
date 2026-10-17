import 'dart:math';

import 'package:flutter/material.dart';

import '../../games/mini_games.dart';
import '../../theme/app_theme.dart';
import 'bot_personas.dart';
import 'game_kit.dart';

// Tic-tac-toe (X and O): against the phone at three levels, or two players on
// one phone. X always moves first. Against the phone the starting side
// alternates after every game.
class TicTacToeGameScreen extends StatefulWidget {
  const TicTacToeGameScreen({super.key, required this.isArabic});

  final bool isArabic;

  @override
  State<TicTacToeGameScreen> createState() => _TicTacToeGameScreenState();
}

class _TicTacToeGameScreenState extends State<TicTacToeGameScreen> {
  final Random _rng = Random();
  int _mode = 0;
  int _level = 1;
  bool _phoneFirst = false;
  List<int> _board = List<int>.filled(9, 0);
  int _turn = 1;
  bool _thinking = false;
  int _gameToken = 0;
  List<int> _score = <int>[0, 0, 0];
  int _confetti = 0;

  late final BotPersona _bot = BotCast.draw(const <int>[1]).at(1)!;
  bool get _ar => widget.isArabic;
  String _t(String ar, String en) => _ar ? ar : en;
  int get _winner => tttWinner(_board);
  bool get _finished => _winner != 0 || tttFull(_board);
  int get _phoneSide => _phoneFirst ? 1 : 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePhoneMove());
  }

  void _newGame({bool keepScore = true, bool toggleStarter = true}) {
    _gameToken++;
    setState(() {
      if (_mode == 0 && toggleStarter) _phoneFirst = !_phoneFirst;
      if (_mode != 0) _phoneFirst = false;
      if (!keepScore) _score = <int>[0, 0, 0];
      _board = List<int>.filled(9, 0);
      _turn = 1;
      _thinking = false;
    });
    _maybePhoneMove();
  }

  void _resetAll() {
    _phoneFirst = true;
    _newGame(keepScore: false);
  }

  void _maybePhoneMove() {
    if (!mounted || _mode != 0 || _finished || _turn != _phoneSide) return;
    final token = _gameToken;
    setState(() => _thinking = true);
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || token != _gameToken || _finished) return;
      final cell = tttBestMove(_board, _phoneSide, _level, _rng);
      setState(() {
        _thinking = false;
        _place(cell);
      });
    });
  }

  // Puts the mark of the side to move on [cell] and records a finished game.
  void _place(int cell) {
    _board[cell] = _turn;
    final winner = _winner;
    if (winner != 0) {
      // Scores follow the people, not the marks: index 0 is you (or the X
      // player), index 1 is the phone (or the O player).
      final who = _mode == 0 ? (winner == _phoneSide ? 1 : 0) : winner - 1;
      _score[who] = _score[who] + 1;
      if (who == 0) _confetti++;
    } else if (tttFull(_board)) {
      _score[2] = _score[2] + 1;
    }
    _turn = _turn == 1 ? 2 : 1;
  }

  void _tap(int cell) {
    if (_finished || _thinking || _board[cell] != 0) return;
    if (_mode == 0 && _turn == _phoneSide) return;
    setState(() => _place(cell));
    _maybePhoneMove();
  }

  String _sideName(int side) {
    if (_mode == 0) {
      return side == _phoneSide ? _bot.name(_ar) : _t('أنت', 'You');
    }
    return side == 1 ? _t('اللاعب X', 'Player X') : _t('اللاعب O', 'Player O');
  }

  List<int> _winningLine() {
    for (final line in tttLines) {
      final a = _board[line[0]];
      if (a != 0 && a == _board[line[1]] && a == _board[line[2]]) return line;
    }
    return const <int>[];
  }

  String _status() {
    final winner = _winner;
    if (winner != 0) {
      if (_mode == 0) {
        return winner == _phoneSide
            ? _t('فاز الهاتف', 'The phone wins')
            : _t('🎉 فزت!', '🎉 You win!');
      }
      return _t('🎉 فاز ${_sideName(winner)}', '🎉 ${_sideName(winner)} wins');
    }
    if (tttFull(_board)) return _t('تعادل', 'Draw');
    if (_thinking) return _t('الهاتف يفكر...', 'The phone is thinking...');
    return _t('الدور: ${_sideName(_turn)}', 'Turn: ${_sideName(_turn)}');
  }

  @override
  Widget build(BuildContext context) {
    final line = _winningLine();
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: GameScaffold(
        title: _t('إكس أو', 'Tic-Tac-Toe'),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                GameModeSwitch<int>(
                  choices: <GameChoice<int>>[
                    GameChoice<int>(0, _t('ضد الهاتف', 'vs Phone')),
                    GameChoice<int>(1, _t('لاعبان', 'Two players')),
                  ],
                  selected: _mode,
                  onChanged: (value) {
                    _mode = value;
                    _resetAll();
                  },
                ),
                if (_mode == 0) const SizedBox(height: 10),
                if (_mode == 0)
                  GameModeSwitch<int>(
                    choices: <GameChoice<int>>[
                      GameChoice<int>(0, _t('سهل', 'Easy')),
                      GameChoice<int>(1, _t('متوسط', 'Medium')),
                      GameChoice<int>(2, _t('صعب', 'Hard')),
                    ],
                    selected: _level,
                    onChanged: (value) {
                      _level = value;
                      _resetAll();
                    },
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GameScoreChip(
                      label: _mode == 0 ? _t('أنت', 'You') : 'X',
                      value: '${_score[0]}',
                      active: !_finished && _turn == (_mode == 0 ? (_phoneFirst ? 2 : 1) : 1),
                    ),
                    GameScoreChip(
                      label: _t('تعادل', 'Draws'),
                      value: '${_score[2]}',
                      accent: kGameGold,
                    ),
                    GameScoreChip(
                      avatar: _mode == 0 ? BotAvatar(persona: _bot, size: 28) : null,
                      label: _mode == 0 ? _bot.name(_ar) : 'O',
                      value: '${_score[1]}',
                      accent: const Color(0xFFFF5C8A),
                      active: !_finished && _turn == (_mode == 0 ? _phoneSide : 2),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: GameBanner(
                    text: _status(),
                    color: _finished ? kGameGold : Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: GamePanel(
                      padding: const EdgeInsets.all(10),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Stack(
                          children: [
                            Column(
                              children: [
                                for (var r = 0; r < 3; r++)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        for (var c = 0; c < 3; c++)
                                          Expanded(
                                            child: _cell(r * 3 + c,
                                                line.contains(r * 3 + c)),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (line.isNotEmpty)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: TweenAnimationBuilder<double>(
                                    key: ValueKey<String>('win_${line.join()}'),
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOut,
                                    builder: (context, value, child) =>
                                        CustomPaint(
                                      painter: _WinLinePainter(line, value),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_finished)
                  Center(
                    child: GameButton(
                      onPressed: () => _newGame(),
                      icon: Icons.refresh_rounded,
                      label: _t('لعبة جديدة', 'New game'),
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

  Widget _cell(int index, bool highlighted) {
    final mark = _board[index];
    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_board[index] == 0) gameTap();
          _tap(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: highlighted
                ? Colors.white.withOpacity(0.24)
                : Colors.black.withOpacity(0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? kGameGold : Colors.white.withOpacity(0.12),
              width: highlighted ? 2 : 1,
            ),
          ),
          child: Center(
            child: mark == 0
                ? const SizedBox.shrink()
                : TweenAnimationBuilder<double>(
                    key: ValueKey<String>('mark_${index}_$mark'),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) => Transform.scale(
                      scale: value.clamp(0.0, 1.3).toDouble(),
                      child: child,
                    ),
                    child: mark == 1
                        ? const Icon(Icons.close_rounded,
                            size: 64, color: kGameTeal)
                        : Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFF5C8A),
                                width: 9,
                              ),
                            ),
                          ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _WinLinePainter extends CustomPainter {
  _WinLinePainter(this.line, this.progress);

  final List<int> line;
  final double progress;

  Offset _center(int index, Size size) {
    final cell = size.width / 3;
    return Offset((index % 3 + 0.5) * cell, (index ~/ 3 + 0.5) * cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (line.length != 3) return;
    final a = _center(line[0], size);
    final b = _center(line[2], size);
    final end = Offset.lerp(a, b, progress)!;
    final glow = Paint()
      ..color = kGameGold.withOpacity(0.45)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    final core = Paint()
      ..color = kGameGold
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, end, glow);
    canvas.drawLine(a, end, core);
  }

  @override
  bool shouldRepaint(covariant _WinLinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.line != line;
}
