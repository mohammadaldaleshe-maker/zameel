import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../games/mini_games.dart';
import '../../theme/app_theme.dart';

// Dice duel: both sides roll one or two dice, the higher total wins the round,
// a tie is rolled again. The first side to win five rounds takes the match.
class DiceGameScreen extends StatefulWidget {
  const DiceGameScreen({super.key, required this.isArabic});

  final bool isArabic;

  @override
  State<DiceGameScreen> createState() => _DiceGameScreenState();
}

class _DiceGameScreenState extends State<DiceGameScreen> {
  static const int _target = 5;
  final Random _rng = Random();
  Timer? _timer;
  int _mode = 0;
  int _diceCount = 1;
  List<int> _wins = <int>[0, 0];
  List<int> _first = <int>[0];
  List<int> _second = <int>[0];
  bool _rolling = false;
  int _result = -1;

  bool get _ar => widget.isArabic;
  String _t(String ar, String en) => _ar ? ar : en;
  bool get _over => _wins[0] >= _target || _wins[1] >= _target;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _name(int side) {
    if (_mode == 0) {
      return side == 0 ? _t('أنت', 'You') : _t('الهاتف', 'Phone');
    }
    return side == 0 ? _t('اللاعب ١', 'Player 1') : _t('اللاعب ٢', 'Player 2');
  }

  void _roll() {
    if (_rolling || _over) return;
    _timer?.cancel();
    var ticks = 0;
    setState(() {
      _rolling = true;
      _result = -1;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      ticks++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (ticks < 9) {
        setState(() {
          _first = rollDice(_rng, _diceCount);
          _second = rollDice(_rng, _diceCount);
        });
        return;
      }
      timer.cancel();
      setState(() {
        _first = rollDice(_rng, _diceCount);
        _second = rollDice(_rng, _diceCount);
        _rolling = false;
        final a = diceTotal(_first);
        final b = diceTotal(_second);
        if (a > b) {
          _result = 1;
          _wins[0] = _wins[0] + 1;
        } else if (b > a) {
          _result = 2;
          _wins[1] = _wins[1] + 1;
        } else {
          _result = 0;
        }
      });
    });
  }

  void _newGame() {
    _timer?.cancel();
    setState(() {
      _wins = <int>[0, 0];
      _first = List<int>.filled(_diceCount, 0);
      _second = List<int>.filled(_diceCount, 0);
      _rolling = false;
      _result = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String resultText = '';
    if (_result == 0) {
      resultText = _t('تعادل! ارمِ مرة أخرى', 'Tie! Roll again');
    } else if (_result > 0) {
      final winner = _result == 1 ? 0 : 1;
      resultText = _mode == 0
          ? (winner == 0
              ? _t('ربحت الجولة 🎉', 'You won the round 🎉')
              : _t('ربح الهاتف الجولة', 'The phone won the round'))
          : _t('${_name(winner)} ربح الجولة', '${_name(winner)} won the round');
    }
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(_t('النرد', 'Dice'))),
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
                _newGame();
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: <ButtonSegment<int>>[
                ButtonSegment<int>(
                  value: 1,
                  label: Text(_t('نردة واحدة', 'One die')),
                ),
                ButtonSegment<int>(
                  value: 2,
                  label: Text(_t('نردتان', 'Two dice')),
                ),
              ],
              selected: <int>{_diceCount},
              onSelectionChanged: (selection) {
                _diceCount = selection.first;
                _newGame();
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _scoreBox(_name(0), _wins[0], scheme),
                _scoreBox(_name(1), _wins[1], scheme),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _t('أول من يربح $_target جولات يفوز', 'First to win $_target rounds'),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
            _diceRow(_name(0), _first),
            const SizedBox(height: 20),
            _diceRow(_name(1), _second),
            const SizedBox(height: 16),
            Center(
              child: Text(
                resultText,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
            else
              FilledButton.icon(
                onPressed: _rolling ? null : _roll,
                icon: const Icon(Icons.casino_rounded),
                label: Text(_t('ارمِ النرد', 'Roll the dice')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scoreBox(String label, int value, ColorScheme scheme) {
    return Container(
      width: 120,
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

  Widget _diceRow(String label, List<int> values) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final value in values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _DieFace(value: value),
              ),
          ],
        ),
        if (values.length > 1 && values.first > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_t('المجموع: ${diceTotal(values)}', 'Total: ${diceTotal(values)}')),
          ),
      ],
    );
  }
}

class _DieFace extends StatelessWidget {
  const _DieFace({required this.value});

  final int value;

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
    final pips = _pips[value];
    return Container(
      width: 70,
      height: 70,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0B4C0)),
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
                                  color: Color(0xFF212121),
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
    );
  }
}
