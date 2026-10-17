import 'dart:math';

import 'package:flutter/material.dart';

import '../../games/mini_games.dart';
import '../../theme/app_theme.dart';
import 'game_kit.dart';

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
  int _confetti = 0;

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
    if (_over && (_mode == 1 || _wins[0] > _wins[1])) _confetti++;
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
    final revealed = _result >= 0;
    final youWon = _over && _wins[0] > _wins[1];
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: GameScaffold(
        title: _t('حجر ورقة مقص', 'Rock Paper Scissors'),
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
                    setState(() => _mode = value);
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
                      active: revealed && _result == 1,
                    ),
                    GameScoreChip(
                      label: _t('تعادل', 'Draws'),
                      value: '$_draws',
                      accent: kGameGold,
                      active: revealed && _result == 0,
                    ),
                    GameScoreChip(
                      label: _name(1),
                      value: '${_wins[1]}',
                      accent: const Color(0xFFFF5C8A),
                      active: revealed && _result == 2,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _t('أول من يصل إلى $_target يفوز', 'First to $_target wins'),
                    style: TextStyle(color: Colors.white.withOpacity(0.75)),
                  ),
                ),
                const SizedBox(height: 18),
                GamePanel(
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 150,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _arena(_name(0), revealed ? _first : null,
                                revealed && _result == 1,
                                waiting: !revealed && _mode == 1 && _first != null),
                            Text(
                              'VS',
                              style: TextStyle(
                                color: kGameGold,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                shadows: <Shadow>[
                                  Shadow(
                                      color: kGameGold.withOpacity(0.6),
                                      blurRadius: 12),
                                ],
                              ),
                            ),
                            _arena(_name(1), revealed ? _second : null,
                                revealed && _result == 2,
                                waiting: false),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GameBanner(
                        text: revealed ? _resultText() : _prompt(),
                        size: revealed ? 20 : 16,
                        color: revealed ? kGameGold : Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_over)
                  GameResultCard(
                    won: youWon || _mode == 1,
                    title: _matchTitle(),
                    child: GameButton(
                      onPressed: _newGame,
                      icon: Icons.refresh_rounded,
                      label: _t('مباراة جديدة', 'New match'),
                    ),
                  )
                else if (revealed)
                  Center(
                    child: GameButton(
                      onPressed: _nextRound,
                      icon: Icons.play_arrow_rounded,
                      label: _t('الجولة التالية', 'Next round'),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final move in RpsMove.values) _moveButton(move),
                    ],
                  ),
              ],
            ),
            Positioned.fill(child: ConfettiBurst(trigger: _confetti)),
          ],
        ),
      ),
    );
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

  Widget _arena(String label, RpsMove? move, bool winner,
      {required bool waiting}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey<String>('arena_${label}_${move?.index}_$_wins'),
          tween: Tween<double>(begin: 0.3, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, v, child) =>
              Transform.scale(scale: v, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: winner
                    ? const <Color>[Color(0xFFFFE08A), kGameGold]
                    : <Color>[
                        Colors.white.withOpacity(0.22),
                        Colors.white.withOpacity(0.08),
                      ],
              ),
              border: Border.all(
                color: winner ? Colors.white : Colors.white.withOpacity(0.3),
                width: winner ? 3 : 1.5,
              ),
              boxShadow: winner
                  ? <BoxShadow>[
                      BoxShadow(color: kGameGold.withOpacity(0.6), blurRadius: 20),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Center(
              child: Text(
                move != null ? _emoji(move) : (waiting ? '✔️' : '❔'),
                style: TextStyle(fontSize: move != null ? 50 : 38),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          move != null ? _label(move) : label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (move != null)
          Text(label,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
      ],
    );
  }

  Widget _moveButton(RpsMove move) {
    return GestureDetector(
      onTap: () {
        gameTap();
        _pick(move);
      },
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppTheme.primary, AppTheme.primaryDark],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.35)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(_emoji(move), style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 4),
            Text(
              _label(move),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
