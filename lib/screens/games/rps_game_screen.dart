import 'dart:math';

import 'package:flutter/material.dart';

import '../../games/mini_games.dart';
import '../../theme/app_theme.dart';

// Rock paper scissors: against the phone or two players on one phone.
// The first side to reach three round wins takes the match.
class RpsGameScreen extends StatefulWidget {
  const RpsGameScreen({super.key, required this.isArabic});

  final bool isArabic;

  @override
  State<RpsGameScreen> createState() => _RpsGameScreenState();
}

class _RpsGameScreenState extends State<RpsGameScreen> {
  static const int _target = 3;
  final Random _rng = Random();
  int _mode = 0;
  List<int> _wins = <int>[0, 0];
  int _draws = 0;
  RpsMove? _first;
  RpsMove? _second;
  int _result = -1;

  bool get _ar => widget.isArabic;
  String _t(String ar, String en) => _ar ? ar : en;
  bool get _over => _wins[0] >= _target || _wins[1] >= _target;

  String _name(int side) {
    if (_mode == 0) {
      return side == 0 ? _t('أنت', 'You') : _t('الهاتف', 'Phone');
    }
    return side == 0 ? _t('اللاعب ١', 'Player 1') : _t('اللاعب ٢', 'Player 2');
  }

  String _emoji(RpsMove move) {
    return switch (move) {
      RpsMove.rock => '✊',
      RpsMove.paper => '✋',
      RpsMove.scissors => '✌️',
    };
  }

  String _label(RpsMove move) {
    return switch (move) {
      RpsMove.rock => _t('حجر', 'Rock'),
      RpsMove.paper => _t('ورقة', 'Paper'),
      RpsMove.scissors => _t('مقص', 'Scissors'),
    };
  }

  void _pick(RpsMove move) {
    if (_result >= 0 || _over) return;
    setState(() {
      if (_mode == 0) {
        _first = move;
        _second = rpsBotMove(_rng);
        _finishRound();
      } else if (_first == null) {
        _first = move;
      } else {
        _second = move;
        _finishRound();
      }
    });
  }

  void _finishRound() {
    final outcome = rpsOutcome(_first!, _second!);
    _result = outcome;
    if (outcome == 1) {
      _wins[0] = _wins[0] + 1;
    } else if (outcome == 2) {
      _wins[1] = _wins[1] + 1;
    } else {
      _draws++;
    }
  }

  void _nextRound() {
    setState(() {
      _first = null;
      _second = null;
      _result = -1;
    });
  }

  void _newGame() {
    setState(() {
      _wins = <int>[0, 0];
      _draws = 0;
      _first = null;
      _second = null;
      _result = -1;
    });
  }

  String _resultText() {
    if (_result == 0) return _t('تعادل!', 'Draw!');
    final winner = _result == 1 ? 0 : 1;
    if (_mode == 0) {
      return winner == 0 ? _t('ربحت الجولة 🎉', 'You won the round 🎉') : _t('ربح الهاتف الجولة', 'The phone won the round');
    }
    return _t('${_name(winner)} ربح الجولة', '${_name(winner)} won the round');
  }

  String _prompt() {
    if (_mode == 0) return _t('اختر حركتك', 'Choose your move');
    if (_first == null) {
      return _t('اللاعب ١: اختر حركتك', 'Player 1: choose your move');
    }
    return _t('اللاعب ٢: اختر حركتك (لا تدع الأول يرى)', 'Player 2: choose (hide it from player 1)');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final revealed = _result >= 0;
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(_t('حجر ورقة مقص', 'Rock Paper Scissors'))),
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
                setState(() => _mode = selection.first);
                _newGame();
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _scoreBox(_name(0), _wins[0], scheme),
                _scoreBox(_t('تعادل', 'Draws'), _draws, scheme),
                _scoreBox(_name(1), _wins[1], scheme),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _t('أول من يصل إلى $_target يفوز', 'First to $_target wins'),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
            if (revealed)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _moveBox(_name(0), _first!),
                  _moveBox(_name(1), _second!),
                ],
              ),
            if (revealed) const SizedBox(height: 16),
            if (revealed)
              Center(
                child: Text(
                  _resultText(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (_over)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Text(
                    _wins[0] > _wins[1]
                        ? (_mode == 0
                            ? _t('🏆 فزت بالمباراة!', '🏆 You won the match!')
                            : _t('🏆 فاز اللاعب ١', '🏆 Player 1 wins'))
                        : (_mode == 0
                            ? _t('فاز الهاتف بالمباراة', 'The phone won the match')
                            : _t('🏆 فاز اللاعب ٢', '🏆 Player 2 wins')),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (_over)
              FilledButton.icon(
                onPressed: _newGame,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_t('مباراة جديدة', 'New match')),
              )
            else if (revealed)
              FilledButton.icon(
                onPressed: _nextRound,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(_t('الجولة التالية', 'Next round')),
              )
            else ...[
              Center(
                child: Text(
                  _prompt(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final move in RpsMove.values) _moveButton(move),
                ],
              ),
            ],
          ],
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

  Widget _moveBox(String label, RpsMove move) {
    return Column(
      children: [
        Text(_emoji(move), style: const TextStyle(fontSize: 64)),
        Text(_label(move)),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _moveButton(RpsMove move) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _pick(move),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(_emoji(move), style: const TextStyle(fontSize: 52)),
            Text(_label(move)),
          ],
        ),
      ),
    );
  }
}
