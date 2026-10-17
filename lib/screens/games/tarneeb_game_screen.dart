import 'package:flutter/material.dart';

import '../../games/cards.dart';
import '../../games/tarneeb.dart';
import '../../theme/app_theme.dart';
import 'game_kit.dart';
import 'game_widgets.dart';

// Tarneeb against three bots. You sit at the bottom (south); your partner is
// at the top. Rules are described in lib/games/tarneeb.dart.
class TarneebGameScreen extends StatefulWidget {
  const TarneebGameScreen({super.key, required this.isArabic});

  final bool isArabic;

  @override
  State<TarneebGameScreen> createState() => _TarneebGameScreenState();
}

class _TarneebGameScreenState extends State<TarneebGameScreen> {
  TarneebGame _game = TarneebGame();
  bool _busy = false;
  bool _showLast = false;

  bool get _ar => widget.isArabic;
  String _t(String ar, String en) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _advance());
  }

  Future<void> _pause(int milliseconds) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));

  // Lets the bots act until it is the human's turn or the hand is over.
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
        if (game.phase == TarneebPhase.bidding) {
          if (game.turn == 0) return;
          await _pause(700);
          if (!mounted || startedWith != _game) return;
          final bid = tarneebBotBid(game.hands[game.turn], game.legalBids());
          setState(() => game.placeBid(bid));
        } else if (game.phase == TarneebPhase.chooseTrump) {
          if (game.highBidder == 0) return;
          await _pause(800);
          if (!mounted || startedWith != _game) return;
          final suit = tarneebBotTrump(game.hands[game.highBidder]);
          setState(() => game.chooseTrump(suit));
        } else if (game.phase == TarneebPhase.playing) {
          if (game.turn == 0) return;
          await _pause(750);
          if (!mounted || startedWith != _game) return;
          final card = tarneebBotPlay(game, game.turn);
          setState(() {
            _showLast = game.play(card);
          });
        } else {
          return;
        }
      }
    } finally {
      // A newly started game owns the flag; an abandoned loop must not clear it.
      if (startedWith == _game) _busy = false;
    }
  }

  void _bidUser(int bid) {
    if (_busy || _game.phase != TarneebPhase.bidding || _game.turn != 0) return;
    setState(() => _game.placeBid(bid));
    _advance();
  }

  void _trumpUser(Suit suit) {
    if (_busy ||
        _game.phase != TarneebPhase.chooseTrump ||
        _game.highBidder != 0) return;
    setState(() => _game.chooseTrump(suit));
    _advance();
  }

  void _playUser(PlayingCard card) {
    if (_busy || _game.phase != TarneebPhase.playing || _game.turn != 0) return;
    if (!_game.legalPlays(0).contains(card)) return;
    setState(() {
      _showLast = _game.play(card);
    });
    _advance();
  }

  void _nextHand() {
    if (_game.phase != TarneebPhase.handOver) return;
    setState(() => _game.nextHand());
    _advance();
  }

  void _restart() {
    _busy = false;
    setState(() {
      _game = TarneebGame();
      _showLast = false;
    });
    _advance();
  }

  Future<void> _confirmRestart() async {
    if (await confirmNewGame(context, _ar) && mounted) _restart();
  }

  String _bidText(int seat) {
    final game = _game;
    if (game.phase == TarneebPhase.bidding) {
      for (var i = 0; i < game.bids.length; i++) {
        if ((game.dealer + 1 + i) % 4 == seat) {
          return game.bids[i] == 0 ? _t('تمرير', 'Pass') : '${game.bids[i]}';
        }
      }
      return '';
    }
    if (seat == game.highBidder) {
      return _t('مزايدة ${game.highBid}', 'Bid ${game.highBid}');
    }
    return '';
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
          title: _t('الطرنيب', 'Tarneeb'),
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
                          _scoreBar(game),
                          const SizedBox(height: 8),
                          _infoLine(game),
                          const SizedBox(height: 8),
                          _table(game),
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
                  trigger: game.phase == TarneebPhase.gameOver &&
                          game.winnerTeam == 0
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

  Widget _scoreBar(TarneebGame game) {
    final usActive = game.phase == TarneebPhase.playing && game.turn % 2 == 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GameScoreChip(
          label: '${_t('نحن', 'Us')} • ${_t('لمّات', 'tricks')} ${game.tricksWon[0]}',
          value: '${game.score[0]}',
          active: usActive && !_showLast,
        ),
        Column(
          children: [
            const Icon(Icons.flag_rounded, color: kGameGold, size: 20),
            Text(
              _t('الهدف ${game.targetScore}', 'Target ${game.targetScore}'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
        GameScoreChip(
          label: '${_t('هم', 'Them')} • ${_t('لمّات', 'tricks')} ${game.tricksWon[1]}',
          value: '${game.score[1]}',
          accent: const Color(0xFFFF5C8A),
          active: game.phase == TarneebPhase.playing &&
              game.turn % 2 == 1 &&
              !_showLast,
        ),
      ],
    );
  }

  Widget _infoLine(TarneebGame game) {
    String text;
    if (game.phase == TarneebPhase.bidding) {
      text = _t('المزايدة — اليد ${game.handNumber}', 'Bidding — hand ${game.handNumber}');
    } else if (game.phase == TarneebPhase.chooseTrump) {
      text = _t('${gameSeatName(game.highBidder, _ar, teams: true)} يختار الورق الرابح', '${gameSeatName(game.highBidder, _ar, teams: true)} chooses trump');
    } else {
      final trump = game.trump;
      final suit = trump == null ? '' : suitSymbol(trump);
      text = _t(
        'المزايدة ${game.highBid} (${gameSeatName(game.highBidder, _ar, teams: true)}) — الرابح $suit',
        'Bid ${game.highBid} (${gameSeatName(game.highBidder, _ar, teams: true)}) — Trump $suit',
      );
    }
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

  Widget _seatBadge(int seat, TarneebGame game, {bool compact = false}) {
    final active = !_showLast &&
        (game.phase == TarneebPhase.playing ||
            game.phase == TarneebPhase.bidding ||
            game.phase == TarneebPhase.chooseTrump) &&
        (game.phase == TarneebPhase.chooseTrump
            ? game.highBidder == seat
            : game.turn == seat);
    final bid = _bidText(seat);
    return GameSeatBadge(
      compact: compact,
      seat: seat,
      name: gameSeatName(seat, _ar, teams: true),
      active: active,
      subtitle: bid.isEmpty
          ? '${game.hands[seat].length} ${_t('ورقة', 'cards')}'
          : bid,
    );
  }

  Widget _table(TarneebGame game) {
    final plays = _showLast ? game.lastTrick : game.trick;
    return GameFeltTable(
      height: 330,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _seatBadge(2, game),
                  const SizedBox(height: 4),
                  CardBackFan(count: game.hands[2].length, width: 24),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _seatBadge(1, game, compact: true),
                  const SizedBox(height: 4),
                  CardBackFan(
                      count: game.hands[1].length, width: 22, vertical: true),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _seatBadge(3, game, compact: true),
                  const SizedBox(height: 4),
                  CardBackFan(
                      count: game.hands[3].length, width: 22, vertical: true),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _seatBadge(0, game),
            ),
          ),
          Center(child: TrickArea(plays: plays, cardWidth: 42, size: 150)),
        ],
      ),
    );
  }

  Widget _suitButton(Suit suit) {
    return GestureDetector(
      onTap: () {
        gameTap();
        _trumpUser(suit);
      },
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: <Color>[Colors.white, Color(0xFFE3E7F6)],
          ),
          border: Border.all(color: kGameGold, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(color: kGameGold.withOpacity(0.4), blurRadius: 10),
          ],
        ),
        child: Center(
          child: Text(
            suitSymbol(suit),
            style: TextStyle(fontSize: 32, color: suitColor(suit), height: 1.0),
          ),
        ),
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

  Widget _actionPanel(TarneebGame game) {
    if (game.phase == TarneebPhase.bidding && game.turn == 0) {
      return GamePanel(
        child: Column(
          children: [
            _panelTitle(_t('دورك للمزايدة', 'Your turn to bid')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final bid in game.legalBids())
                  bid == 0
                      ? GameButton(
                          primary: false,
                          onPressed: _busy ? null : () => _bidUser(0),
                          label: _t('تمرير', 'Pass'),
                        )
                      : SizedBox(
                          width: 76,
                          child: GameButton(
                            onPressed: _busy ? null : () => _bidUser(bid),
                            label: '$bid',
                          ),
                        ),
              ],
            ),
          ],
        ),
      );
    }
    if (game.phase == TarneebPhase.chooseTrump && game.highBidder == 0) {
      return GamePanel(
        child: Column(
          children: [
            _panelTitle(_t('اختر الورق الرابح', 'Choose the trump suit')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final suit in allSuits) _suitButton(suit),
              ],
            ),
          ],
        ),
      );
    }
    if (_showLast) {
      return GameBanner(
        size: 16,
        color: kGameGold,
        text: _t('${gameSeatName(game.lastTrickWinner, _ar, teams: true)} ربح اللمّة',
            '${gameSeatName(game.lastTrickWinner, _ar, teams: true)} won the trick'),
      );
    }
    if (game.phase == TarneebPhase.playing) {
      return GameBanner(
        size: 15,
        text: game.turn == 0
            ? _t('دورك — اختر ورقة', 'Your turn — play a card')
            : _t('ينتظر ${gameSeatName(game.turn, _ar, teams: true)}...',
                'Waiting for ${gameSeatName(game.turn, _ar, teams: true)}...'),
      );
    }
    if (game.phase == TarneebPhase.handOver ||
        game.phase == TarneebPhase.gameOver) {
      return _summaryCard(game);
    }
    return const SizedBox.shrink();
  }

  Widget _summaryCard(TarneebGame game) {
    final bidTeam = game.highBidder % 2;
    final made = game.tricksWon[bidTeam] >= game.highBid;
    final over = game.phase == TarneebPhase.gameOver;
    final won = over && game.winnerTeam == 0;
    final handText = made
        ? _t('حقق فريق المزايدة مزايدته (${game.highBid})',
            'The bidding team made its bid (${game.highBid})')
        : _t('فشل فريق المزايدة (${game.highBid})',
            'The bidding team failed (${game.highBid})');
    return GameResultCard(
      won: over ? won : made == (bidTeam == 0),
      title: over
          ? (won
              ? _t('🏆 فزتم بالمباراة!', '🏆 Your team won the game!')
              : _t('خسرتم المباراة', 'Your team lost the game'))
          : handText,
      child: Column(
        children: [
          if (over)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                handText,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
            ),
          Text(
            _t(
              'نحن ${game.lastHandDelta[0] >= 0 ? '+' : ''}${game.lastHandDelta[0]}   •   هم ${game.lastHandDelta[1] >= 0 ? '+' : ''}${game.lastHandDelta[1]}',
              'Us ${game.lastHandDelta[0] >= 0 ? '+' : ''}${game.lastHandDelta[0]}   •   Them ${game.lastHandDelta[1] >= 0 ? '+' : ''}${game.lastHandDelta[1]}',
            ),
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          GameButton(
            onPressed: over ? _restart : _nextHand,
            icon: over ? Icons.refresh_rounded : Icons.play_arrow_rounded,
            label: over ? _t('لعبة جديدة', 'New game') : _t('اليد التالية', 'Next hand'),
          ),
        ],
      ),
    );
  }

  Widget _handRow(TarneebGame game) {
    final canPlay = game.phase == TarneebPhase.playing &&
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
