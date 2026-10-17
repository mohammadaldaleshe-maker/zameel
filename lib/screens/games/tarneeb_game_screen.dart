import 'package:flutter/material.dart';

import '../../games/cards.dart';
import '../../games/tarneeb.dart';
import '../../theme/app_theme.dart';
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
    try {
      while (mounted) {
        if (_showLast) {
          await _pause(1300);
          if (!mounted) return;
          setState(() => _showLast = false);
        }
        final game = _game;
        if (game.phase == TarneebPhase.bidding) {
          if (game.turn == 0) return;
          await _pause(700);
          if (!mounted) return;
          final bid = tarneebBotBid(game.hands[game.turn], game.legalBids());
          setState(() => game.placeBid(bid));
        } else if (game.phase == TarneebPhase.chooseTrump) {
          if (game.highBidder == 0) return;
          await _pause(800);
          if (!mounted) return;
          final suit = tarneebBotTrump(game.hands[game.highBidder]);
          setState(() => game.chooseTrump(suit));
        } else if (game.phase == TarneebPhase.playing) {
          if (game.turn == 0) return;
          await _pause(750);
          if (!mounted) return;
          final card = tarneebBotPlay(game, game.turn);
          setState(() {
            _showLast = game.play(card);
          });
        } else {
          return;
        }
      }
    } finally {
      _busy = false;
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
        child: Scaffold(
          appBar: AppBar(
            title: Text(_t('الطرنيب', 'Tarneeb')),
            actions: [
              IconButton(
                tooltip: _t('لعبة جديدة', 'New game'),
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _confirmRestart,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      children: [
                        _scoreBar(game),
                        const SizedBox(height: 8),
                        _infoLine(game),
                        const SizedBox(height: 8),
                        _table(game),
                        const SizedBox(height: 8),
                        _actionPanel(game),
                      ],
                    ),
                  ),
                ),
                _handRow(game),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreBar(TarneebGame game) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GamePill(
          text: '${_t('نحن', 'Us')}: ${game.score[0]}',
          subtitle: _t('اللمّات: ${game.tricksWon[0]}', 'Tricks: ${game.tricksWon[0]}'),
        ),
        Text(
          _t('الهدف ${game.targetScore}', 'Target ${game.targetScore}'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        GamePill(
          text: '${_t('هم', 'Them')}: ${game.score[1]}',
          subtitle: _t('اللمّات: ${game.tricksWon[1]}', 'Tricks: ${game.tricksWon[1]}'),
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
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  Widget _seatBadge(int seat, TarneebGame game) {
    final active = !_showLast &&
        (game.phase == TarneebPhase.playing ||
            game.phase == TarneebPhase.bidding ||
            game.phase == TarneebPhase.chooseTrump) &&
        (game.phase == TarneebPhase.chooseTrump
            ? game.highBidder == seat
            : game.turn == seat);
    final bid = _bidText(seat);
    return GamePill(
      text: gameSeatName(seat, _ar, teams: true),
      active: active,
      subtitle: bid.isEmpty
          ? '${game.hands[seat].length} ${_t('ورقة', 'cards')}'
          : bid,
    );
  }

  Widget _trickArea(TarneebGame game) {
    final plays = _showLast ? game.lastTrick : game.trick;
    PlayingCard? cardOf(int seat) {
      for (final p in plays) {
        if (p.seat == seat) return p.card;
      }
      return null;
    }

    Widget slot(int seat, Alignment alignment) {
      final card = cardOf(seat);
      return Align(
        alignment: alignment,
        child: card == null
            ? const SizedBox(width: 38, height: 54)
            : GameCardView(card: card, width: 38),
      );
    }

    return SizedBox(
      width: 150,
      height: 170,
      child: Stack(
        children: [
          slot(0, Alignment.bottomCenter),
          slot(1, Alignment.centerLeft),
          slot(2, Alignment.topCenter),
          slot(3, Alignment.centerRight),
        ],
      ),
    );
  }

  Widget _table(TarneebGame game) {
    return SizedBox(
      height: 270,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: _seatBadge(2, game),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _seatBadge(1, game),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _seatBadge(3, game),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _seatBadge(0, game),
          ),
          Center(child: _trickArea(game)),
        ],
      ),
    );
  }

  Widget _suitButton(Suit suit) {
    return OutlinedButton(
      onPressed: () => _trumpUser(suit),
      child: Text(
        suitSymbol(suit),
        style: TextStyle(fontSize: 28, color: suitColor(suit)),
      ),
    );
  }

  Widget _actionPanel(TarneebGame game) {
    if (game.phase == TarneebPhase.bidding && game.turn == 0) {
      return Column(
        children: [
          Text(
            _t('دورك للمزايدة', 'Your turn to bid'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final bid in game.legalBids())
                bid == 0
                    ? OutlinedButton(
                        onPressed: _busy ? null : () => _bidUser(0),
                        child: Text(_t('تمرير', 'Pass')),
                      )
                    : FilledButton(
                        onPressed: _busy ? null : () => _bidUser(bid),
                        child: Text('$bid'),
                      ),
            ],
          ),
        ],
      );
    }
    if (game.phase == TarneebPhase.chooseTrump && game.highBidder == 0) {
      return Column(
        children: [
          Text(
            _t('اختر الورق الرابح', 'Choose the trump suit'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final suit in allSuits) _suitButton(suit),
            ],
          ),
        ],
      );
    }
    if (_showLast) {
      return Text(
        _t('${gameSeatName(game.lastTrickWinner, _ar, teams: true)} ربح اللمّة', '${gameSeatName(game.lastTrickWinner, _ar, teams: true)} won the trick'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      );
    }
    if (game.phase == TarneebPhase.playing) {
      return Text(
        game.turn == 0
            ? _t('دورك — اختر ورقة', 'Your turn — play a card')
            : _t('ينتظر ${gameSeatName(game.turn, _ar, teams: true)}...', 'Waiting for ${gameSeatName(game.turn, _ar, teams: true)}...'),
        style: const TextStyle(fontWeight: FontWeight.w700),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              made
                  ? _t('حقق فريق المزايدة مزايدته (${game.highBid})', 'The bidding team made its bid (${game.highBid})')
                  : _t('فشل فريق المزايدة (${game.highBid})', 'The bidding team failed (${game.highBid})'),
              style: const TextStyle(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _t(
                'نحن ${game.lastHandDelta[0] >= 0 ? '+' : ''}${game.lastHandDelta[0]}   •   هم ${game.lastHandDelta[1] >= 0 ? '+' : ''}${game.lastHandDelta[1]}',
                'Us ${game.lastHandDelta[0] >= 0 ? '+' : ''}${game.lastHandDelta[0]}   •   Them ${game.lastHandDelta[1] >= 0 ? '+' : ''}${game.lastHandDelta[1]}',
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 10),
            if (over)
              Text(
                game.winnerTeam == 0
                    ? _t('🏆 فزتم بالمباراة!', '🏆 Your team won the game!')
                    : _t('خسرتم المباراة', 'Your team lost the game'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: over ? _restart : _nextHand,
              icon: Icon(over ? Icons.refresh_rounded : Icons.play_arrow_rounded),
              label: Text(over ? _t('لعبة جديدة', 'New game') : _t('اليد التالية', 'Next hand')),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final card in game.hands[0])
            GameCardView(
              card: card,
              width: 42,
              enabled: !canPlay || legal.contains(card),
              highlight: canPlay && legal.contains(card),
              onTap: canPlay && legal.contains(card)
                  ? () => _playUser(card)
                  : null,
            ),
        ],
      ),
    );
  }
}
