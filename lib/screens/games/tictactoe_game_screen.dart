import 'dart:math';

import 'package:flutter/material.dart';

import '../../games/mini_games.dart';
import '../../theme/app_theme.dart';

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
      return side == _phoneSide ? _t('الهاتف', 'Phone') : _t('أنت', 'You');
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
    final scheme = Theme.of(context).colorScheme;
    final line = _winningLine();
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(_t('إكس أو', 'Tic-Tac-Toe'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<int>(
              segments: <ButtonSegment<int>>[
                ButtonSegment<int>(
                  value: 0,
                  label: Text(_t('ضد الهاتف', 'vs Phone')),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text(_t('لاعبان', 'Two players')),
                ),
              ],
              selected: <int>{_mode},
              onSelectionChanged: (selection) {
                _mode = selection.first;
                _resetAll();
              },
            ),
            if (_mode == 0) const SizedBox(height: 12),
            if (_mode == 0)
              SegmentedButton<int>(
                segments: <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 0, label: Text(_t('سهل', 'Easy'))),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(_t('متوسط', 'Medium')),
                  ),
                  ButtonSegment<int>(value: 2, label: Text(_t('صعب', 'Hard'))),
                ],
                selected: <int>{_level},
                onSelectionChanged: (selection) {
                  _level = selection.first;
                  _resetAll();
                },
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _scoreBox(_mode == 0 ? _t('أنت', 'You') : 'X', _score[0], scheme),
                _scoreBox(_t('تعادل', 'Draws'), _score[2], scheme),
                _scoreBox(_mode == 0 ? _t('الهاتف', 'Phone') : 'O', _score[1], scheme),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _status(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 330),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < 9; i++) _cell(i, line.contains(i), scheme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_finished)
              FilledButton.icon(
                onPressed: () => _newGame(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_t('لعبة جديدة', 'New game')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int index, bool highlighted, ColorScheme scheme) {
    final mark = _board[index];
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _tap(index),
      child: Container(
        decoration: BoxDecoration(
          color: highlighted ? AppTheme.primaryLight : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted ? AppTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            mark == 1 ? 'X' : (mark == 2 ? 'O' : ''),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 54,
              fontWeight: FontWeight.w900,
              color: mark == 1 ? AppTheme.primary : AppTheme.error,
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreBox(String label, int value, ColorScheme scheme) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
