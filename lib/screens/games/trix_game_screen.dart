import 'package:flutter/material.dart';

import '../../games/cards.dart';
import '../../games/trix.dart';
import '../../theme/app_theme.dart';
import 'game_kit.dart';
import 'game_widgets.dart';

// Trix against three bots. Rules are described in lib/games/trix.dart.
class TrixGameScreen extends StatefulWidget {
  const TrixGameScreen({super.key, required this.isArabic});

  final bool isArabic;

  @override
  State<TrixGameScreen> createState() => _TrixGameScreenState();
}

class _TrixGameScreenState extends State<TrixGameScreen> {
  TrixGame _game = TrixGame();
  bool _busy = false;
  bool _showLast = false;
  String _notice = '';

  bool get _ar => widget.isArabic;
  String _t(String ar, String en) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _advance());
  }

  Future<void> _pause(int milliseconds) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));

  String _contractName(TrixContract contract) {
    return switch (contract) {
      TrixContract.kingOfHearts => _t('ملك القلب', 'King of hearts'),
      TrixContract.queens => _t('البنات', 'Queens'),
      TrixContract.diamonds => _t('الديناري', 'Diamonds'),
      TrixContract.collections => _t('اللمّة', 'Collections'),
      TrixContract.trix => _t('تركس', 'Trix'),
    };
  }

  String _contractHelp(TrixContract contract) {
    return switch (contract) {
      TrixContract.kingOfHearts =>
        _t('-75 لمن تقع عنده ورقة ملك القلب', '-75 for whoever takes the king of hearts'),
      TrixContract.queens =>
        _t('-25 على كل بنت تقع عندك', '-25 for every queen you take'),
      TrixContract.diamonds =>
        _t('-10 على كل ورقة ديناري تقع عندك', '-10 for every diamond you take'),
      TrixContract.collections =>
        _t('-15 على كل لمّة تربحها', '-15 for every trick you win'),
      TrixContract.trix =>
        _t('تخلّص من أوراقك أولاً: +200 ثم 150 ثم 100 ثم 50', 'Empty your hand first: +200, 150, 100, 50'),
    };
  }

  // Lets the bots act until it is the human's turn or the deal is over.
  Future<void> _advance() async {
    if (_busy) return;
    _busy = true;
    final startedWith = _game;
    try {
      while (mounted) {
        if (_showLast) {
          await _pause(1300);
          if (!mounted || startedWith != _game) return;
          setState(() => _showLast = false);
        }
        final game = _game;
        if (game.phase == TrixPhase.chooseContract) {
          if (game.owner == 0) return;
          await _pause(900);
          if (!mounted || startedWith != _game) return;
          final choice = trixBotChooseContract(
            game.hands[game.owner],
            game.availableContracts(),
          );
          setState(() {
            _notice = '';
            game.startContract(choice);
          });
        } else if (game.phase == TrixPhase.playing) {
          if (game.currentMustPass) {
            await _pause(game.turn == 0 ? 1000 : 500);
            if (!mounted || startedWith != _game) return;
            final who = game.turn;
            setState(() {
              _notice = _t(
                '${gameSeatName(who, true)} لا يملك ورقة مناسبة — تمرير',
                '${gameSeatName(who, false)} has no playable card — pass',
              );
              game.pass();
            });
          } else if (game.turn == 0) {
            return;
          } else {
            await _pause(700);
            if (!mounted || startedWith != _game) return;
            final card = trixBotPlay(game, game.turn);
            setState(() {
              _notice = '';
              _showLast = game.play(card);
            });
          }
        } else {
          return;
        }
      }
    } finally {
      // A newly started game owns the flag; an abandoned loop must not clear it.
      if (startedWith == _game) _busy = false;
    }
  }

  void _chooseUser(TrixContract contract) {
    if (_busy ||
        _game.phase != TrixPhase.chooseContract ||
        _game.owner != 0) return;
    setState(() {
      _notice = '';
      _game.startContract(contract);
    });
    _advance();
  }

  void _playUser(PlayingCard card) {
    if (_busy || _game.phase != TrixPhase.playing || _game.turn != 0) return;
    if (!_game.legalPlays(0).contains(card)) return;
    setState(() {
      _notice = '';
      _showLast = _game.play(card);
    });
    _advance();
  }

  void _nextDeal() {
    if (_game.phase != TrixPhase.dealOver) return;
    setState(() {
      _notice = '';
      _game.nextDeal();
    });
    _advance();
  }

  void _restart() {
    _busy = false;
    setState(() {
      _game = TrixGame();
      _showLast = false;
      _notice = '';
    });
    _advance();
  }

  Future<void> _confirmRestart() async {
    if (await confirmNewGame(context, _ar) && mounted) _restart();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await confirmLeaveGame(context, _ar);
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Directionality(
        textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
        child: GameScaffold(
          title: _t('التركس', 'Trix'),
          actions: [
            IconButton(
              tooltip: _t('لعبة جديدة', 'New game'),
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _confirmRestart,
            ),
          ],
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: Column(
                        children: [
                          _playersBar(game),
                          const SizedBox(height: 8),
                          _infoLine(game),
                          const SizedBox(height: 8),
                          _tableArea(game),
                          const SizedBox(height: 10),
                          _actionPanel(game),
                        ],
                      ),
                    ),
                  ),
                  _handRow(game),
                ],
              ),
              Positioned.fill(
                child: ConfettiBurst(
                  trigger: game.phase == TrixPhase.gameOver &&
                          game.winners().contains(0)
                      ? 1
                      : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playersBar(TrixGame game) {
    final waiting = game.phase == TrixPhase.playing && !_showLast;
    final choosing = game.phase == TrixPhase.chooseContract;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var seat = 0; seat < 4; seat++)
          GameSeatBadge(
            seat: seat,
            name: gameSeatName(seat, _ar),
            active: (waiting && game.turn == seat) ||
                (choosing && game.owner == seat),
            subtitle:
                '${game.totals[seat]} • ${game.hands[seat].length} ${_t('ورقة', 'cards')}',
          ),
      ],
    );
  }

  Widget _infoLine(TrixGame game) {
    final deal = game.dealIndex + 1;
    final total = trixDeals;
    final kingdom = gameSeatName(game.owner, _ar);
    final chosen = game.contract;
    final text = chosen == null
        ? _t('الصفقة $deal/$total — مملكة $kingdom', 'Deal $deal/$total — $kingdom kingdom')
        : _t(
            'الصفقة $deal/$total — مملكة $kingdom — ${_contractName(chosen)}',
            'Deal $deal/$total — $kingdom kingdom — ${_contractName(chosen)}',
          );
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _tableArea(TrixGame game) {
    if (game.phase == TrixPhase.chooseContract) {
      return const SizedBox(height: 20);
    }
    if (game.isLayout) {
      return GamePanel(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            for (final suit in allSuits) _layoutRow(game, suit),
          ],
        ),
      );
    }
    final plays = _showLast ? game.lastTrick : game.trick;
    return GameFeltTable(
      height: 300,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: CardBackFan(count: game.hands[2].length, width: 24),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: CardBackFan(
                  count: game.hands[1].length, width: 22, vertical: true),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CardBackFan(
                  count: game.hands[3].length, width: 22, vertical: true),
            ),
          ),
          Center(child: TrickArea(plays: plays, cardWidth: 42, size: 150)),
        ],
      ),
    );
  }

  Widget _layoutRow(TrixGame game, Suit suit) {
    final lo = game.low[suit.index];
    final hi = game.high[suit.index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsetsDirectional.only(end: 6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Center(
              child: Text(
                suitSymbol(suit),
                style: TextStyle(
                    fontSize: 20, color: suitColor(suit), height: 1.0),
              ),
            ),
          ),
          Expanded(
            child: lo < 0
                ? const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('—', style: TextStyle(color: Colors.white54)),
                  )
                : Wrap(
                    spacing: 2,
                    runSpacing: 2,
                    children: [
                      for (var r = lo; r <= hi; r++)
                        GameCardView(card: PlayingCard(suit, r), width: 28),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _panelTitle(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 16,
      ),
    );
  }

  Widget _actionPanel(TrixGame game) {
    if (game.phase == TrixPhase.chooseContract) {
      if (game.owner != 0) {
        return GameBanner(
          size: 15,
          text: _t('${gameSeatName(game.owner, true)} يختار العقد...',
              '${gameSeatName(game.owner, false)} is choosing a contract...'),
        );
      }
      return GamePanel(
        child: Column(
          children: [
            _panelTitle(_t('مملكتك — اختر عقداً', 'Your kingdom — choose a contract')),
            const SizedBox(height: 10),
            for (final contract in game.availableContracts())
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[AppTheme.primary, AppTheme.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _busy
                          ? null
                          : () {
                              gameTap();
                              _chooseUser(contract);
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              Text(
                                _contractName(contract),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                _contractHelp(contract),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (_showLast) {
      return GameBanner(
        size: 16,
        color: kGameGold,
        text: _t('${gameSeatName(game.lastTrickWinner, true)} ربح اللمّة',
            '${gameSeatName(game.lastTrickWinner, false)} won the trick'),
      );
    }
    if (game.phase == TrixPhase.playing) {
      final turnText = game.turn == 0
          ? _t('دورك — اختر ورقة', 'Your turn — play a card')
          : _t('ينتظر ${gameSeatName(game.turn, true)}...',
              'Waiting for ${gameSeatName(game.turn, false)}...');
      return Column(
        children: [
          GameBanner(size: 15, text: turnText),
          if (_notice.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _notice,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kGameGold),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _contractHelp(game.contract!),
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    if (game.phase == TrixPhase.dealOver || game.phase == TrixPhase.gameOver) {
      return _summaryCard(game);
    }
    return const SizedBox.shrink();
  }

  Widget _summaryCard(TrixGame game) {
    final over = game.phase == TrixPhase.gameOver;
    final chosen = game.contract;
    final winners = game.winners();
    final won = over && winners.contains(0);
    final title = over
        ? (won
            ? _t('🏆 فزت بالمباراة!', '🏆 You won the game!')
            : _t('🏆 الفائز: ${winners.map((s) => gameSeatName(s, true)).join('، ')}',
                '🏆 Winner: ${winners.map((s) => gameSeatName(s, false)).join(', ')}'))
        : (chosen != null
            ? _t('انتهت صفقة ${_contractName(chosen)}',
                '${_contractName(chosen)} deal finished')
            : '');
    return GameResultCard(
      won: over ? won : true,
      title: title,
      child: Column(
        children: [
          for (var seat = 0; seat < 4; seat++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    gameSeatName(seat, _ar),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: seat == 0 ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${game.lastDealScores[seat]}   →   ${game.totals[seat]}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          GameButton(
            onPressed: over ? _restart : _nextDeal,
            icon: over ? Icons.refresh_rounded : Icons.play_arrow_rounded,
            label: over ? _t('لعبة جديدة', 'New game') : _t('الصفقة التالية', 'Next deal'),
          ),
        ],
      ),
    );
  }

  Widget _handRow(TrixGame game) {
    final canPlay = game.phase == TrixPhase.playing &&
        game.turn == 0 &&
        !_busy &&
        !_showLast;
    final legal = canPlay ? game.legalPlays(0) : <PlayingCard>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.transparent, Colors.black.withOpacity(0.35)],
        ),
      ),
      child: FannedHand(
        cards: game.hands[0],
        canPlay: canPlay,
        legal: legal,
        onPlay: _playUser,
      ),
    );
  }
}
