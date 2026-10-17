import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../games/mini_games.dart';
import '../../theme/app_theme.dart';
import 'game_kit.dart';

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
  int _confetti = 0;

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
        if (_over && (_mode == 1 || _wins[0] > _wins[1])) _confetti++;
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

  String _matchTitle() {
    if (_wins[0] > _wins[1]) {
      return _mode == 0
          ? _t('🏆 فزت بالمباراة!', '🏆 You won the match!')
          : _t('🏆 فاز اللاعب ١', '🏆 Player 1 wins');
    }
    return _mode == 0
        ? _t('فاز الهاتف بالمباراة', 'The phone won the match')
        : _t('🏆 فاز اللاعب ٢', '🏆 Player 2 wins');
  }

  @override
  Widget build(BuildContext context) {
    String resultText = _rolling ? _t('يتم الرمي...', 'Rolling...') : '';
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
      child: GameScaffold(
        title: _t('النرد', 'Dice'),
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
                    _newGame();
                  },
                ),
                const SizedBox(height: 10),
                GameModeSwitch<int>(
                  choices: <GameChoice<int>>[
                    GameChoice<int>(1, _t('نردة واحدة', 'One die')),
                    GameChoice<int>(2, _t('نردتان', 'Two dice')),
                  ],
                  selected: _diceCount,
                  onChanged: (value) {
                    _diceCount = value;
                    _newGame();
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GameScoreChip(
                      label: _name(0),
                      value: '${_wins[0]}',
                      active: _result == 1,
                    ),
                    GameScoreChip(
                      label: _name(1),
                      value: '${_wins[1]}',
                      accent: const Color(0xFFFF5C8A),
                      active: _result == 2,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _t('أول من يربح $_target جولات يفوز',
                        'First to win $_target rounds'),
                    style: TextStyle(color: Colors.white.withOpacity(0.75)),
                  ),
                ),
                const SizedBox(height: 16),
                GamePanel(
                  child: Column(
                    children: [
                      _diceRow(_name(0), _first, _result == 1),
                      Divider(color: Colors.white.withOpacity(0.18), height: 28),
                      _diceRow(_name(1), _second, _result == 2),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 30,
                        child: Center(
                          child: GameBanner(
                            text: resultText,
                            color: kGameGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_over)
                  GameResultCard(
                    won: _mode == 1 || _wins[0] > _wins[1],
                    title: _matchTitle(),
                    child: GameButton(
                      onPressed: _newGame,
                      icon: Icons.refresh_rounded,
                      label: _t('مباراة جديدة', 'New match'),
                    ),
                  )
                else
                  Center(
                    child: GameButton(
                      onPressed: _rolling ? null : _roll,
                      icon: Icons.casino_rounded,
                      label: _t('ارمِ النرد', 'Roll the dice'),
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

  Widget _diceRow(String label, List<int> values, bool winner) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: winner ? kGameGold : Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < values.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: _DieFace(
                  value: values[i],
                  rolling: _rolling,
                  winner: winner,
                  seed: i,
                ),
              ),
          ],
        ),
        if (values.length > 1 && values.first > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _t('المجموع: ${diceTotal(values)}', 'Total: ${diceTotal(values)}'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _DieFace extends StatelessWidget {
  const _DieFace({
    required this.value,
    required this.rolling,
    required this.winner,
    required this.seed,
  });

  final int value;
  final bool rolling;
  final bool winner;
  final int seed;

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
    final tilt = rolling ? (value.isEven ? 0.18 : -0.18) * (seed.isEven ? 1 : -1) : 0.0;
    return AnimatedRotation(
      turns: tilt / 6.2832,
      duration: const Duration(milliseconds: 80),
      child: AnimatedScale(
        scale: rolling ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Colors.white, Color(0xFFDDE2F5)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: winner ? kGameGold : Colors.white,
              width: winner ? 3 : 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: winner
                    ? kGameGold.withOpacity(0.6)
                    : const Color(0x66000000),
                blurRadius: winner ? 18 : 9,
                offset: const Offset(0, 5),
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
                                    width: 12,
                                    height: 12,
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
      ),
    );
  }
}
