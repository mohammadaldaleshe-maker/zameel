// Trix (Levantine rules), pure Dart. No Flutter imports.
//
// Four players, seats 0..3 (0 = you). The game has four "kingdoms" (one per
// seat, seats 0,1,2,3 in that order). In his kingdom the owner chooses one of
// five contracts for each of five deals, never repeating a contract inside his
// own kingdom: 4 x 5 = 20 deals in total. The owner leads every deal.
//
// Contracts
//   kingOfHearts : whoever wins the trick holding the king of hearts gets -75
//   queens       : -25 for every queen in the tricks a player won
//   diamonds     : -10 for every diamond in the tricks a player won
//   collections  : -15 for every trick a player won
//   trix         : layout game. Jacks may be played at any time and start a
//                  suit row; other cards extend a started row by one rank up
//                  or down. A player with no playable card passes. Finishing
//                  order scores +200, +150, +100, +50.
// In the four trick contracts all 13 tricks are played, players must follow
// the led suit when able, there is no trump and the highest card of the led
// suit wins.
import 'dart:math';

import 'cards.dart';

enum TrixContract { kingOfHearts, queens, diamonds, collections, trix }

const List<TrixContract> allTrixContracts = <TrixContract>[
  TrixContract.kingOfHearts,
  TrixContract.queens,
  TrixContract.diamonds,
  TrixContract.collections,
  TrixContract.trix,
];

enum TrixPhase { chooseContract, playing, dealOver, gameOver }

const int trixDeals = 20;
const List<int> trixPlaceScores = <int>[200, 150, 100, 50];

// Penalty points (positive numbers) of one card for a trick contract.
int trixCardPenalty(TrixContract contract, PlayingCard card) {
  return switch (contract) {
    TrixContract.kingOfHearts =>
      (card.suit == Suit.hearts && card.rank == 13) ? 75 : 0,
    TrixContract.queens => card.rank == 12 ? 25 : 0,
    TrixContract.diamonds => card.suit == Suit.diamonds ? 10 : 0,
    TrixContract.collections => 0,
    TrixContract.trix => 0,
  };
}

// Scores (zero or negative) of the four seats for a finished trick contract.
List<int> trixPenaltyScores(
  TrixContract contract,
  List<List<PlayingCard>> taken,
  List<int> tricksWon,
) {
  final scores = <int>[0, 0, 0, 0];
  for (var seat = 0; seat < 4; seat++) {
    var value = 0;
    for (final card in taken[seat]) {
      value -= trixCardPenalty(contract, card);
    }
    if (contract == TrixContract.collections) {
      value -= 15 * tricksWon[seat];
    }
    scores[seat] = value;
  }
  return scores;
}

// Scores of the four seats for a finished layout game; [finished] lists the
// seats in finishing order (all four of them).
List<int> trixLayoutScores(List<int> finished) {
  final scores = <int>[0, 0, 0, 0];
  for (var i = 0; i < finished.length && i < 4; i++) {
    scores[finished[i]] = trixPlaceScores[i];
  }
  return scores;
}

class TrixGame {
  TrixGame({Random? random}) : rng = random ?? Random() {
    _startDeal();
  }

  final Random rng;

  List<List<PlayingCard>> hands = <List<PlayingCard>>[];
  int dealIndex = 0;
  int owner = 0;
  TrixPhase phase = TrixPhase.chooseContract;
  TrixContract? contract;
  List<Set<TrixContract>> used = <Set<TrixContract>>[
    <TrixContract>{},
    <TrixContract>{},
    <TrixContract>{},
    <TrixContract>{},
  ];
  List<int> totals = <int>[0, 0, 0, 0];
  List<int> lastDealScores = <int>[0, 0, 0, 0];
  int turn = 0;
  List<TrickPlay> trick = <TrickPlay>[];
  List<TrickPlay> lastTrick = <TrickPlay>[];
  int lastTrickWinner = -1;
  List<List<PlayingCard>> taken = <List<PlayingCard>>[];
  List<int> tricksWon = <int>[0, 0, 0, 0];
  // Layout state, indexed by Suit.index. -1 means the row has not started.
  List<int> low = <int>[-1, -1, -1, -1];
  List<int> high = <int>[-1, -1, -1, -1];
  List<int> finished = <int>[];

  void _startDeal() {
    owner = dealIndex ~/ 5;
    hands = dealHands(rng);
    contract = null;
    phase = TrixPhase.chooseContract;
    turn = owner;
    trick = <TrickPlay>[];
    lastTrick = <TrickPlay>[];
    lastTrickWinner = -1;
    taken = <List<PlayingCard>>[
      <PlayingCard>[],
      <PlayingCard>[],
      <PlayingCard>[],
      <PlayingCard>[],
    ];
    tricksWon = <int>[0, 0, 0, 0];
    low = <int>[-1, -1, -1, -1];
    high = <int>[-1, -1, -1, -1];
    finished = <int>[];
    lastDealScores = <int>[0, 0, 0, 0];
  }

  List<TrixContract> availableContracts() {
    return allTrixContracts.where((c) => !used[owner].contains(c)).toList();
  }

  void startContract(TrixContract chosen) {
    if (phase != TrixPhase.chooseContract) {
      throw StateError('not choosing a contract');
    }
    if (!availableContracts().contains(chosen)) {
      throw ArgumentError('contract already used');
    }
    used[owner].add(chosen);
    contract = chosen;
    phase = TrixPhase.playing;
    turn = owner;
  }

  bool get isLayout => contract == TrixContract.trix;

  List<PlayingCard> legalPlays(int seat) {
    final hand = hands[seat];
    if (isLayout) {
      final result = <PlayingCard>[];
      for (final c in hand) {
        if (c.rank == 11) {
          result.add(c);
          continue;
        }
        final lo = low[c.suit.index];
        if (lo < 0) continue;
        if (c.rank == lo - 1 || c.rank == high[c.suit.index] + 1) {
          result.add(c);
        }
      }
      return result;
    }
    if (trick.isEmpty) return List<PlayingCard>.from(hand);
    final led = trick.first.card.suit;
    final follow = hand.where((c) => c.suit == led).toList();
    if (follow.isNotEmpty) return follow;
    return List<PlayingCard>.from(hand);
  }

  // In the layout game the current player has no playable card.
  bool get currentMustPass =>
      phase == TrixPhase.playing && isLayout && legalPlays(turn).isEmpty;

  void pass() {
    if (!currentMustPass) {
      throw StateError('player can play');
    }
    _advanceLayout();
  }

  // Plays a card for the seat whose turn it is. Returns true when the card
  // completed a trick (trick contracts only).
  bool play(PlayingCard card) {
    if (phase != TrixPhase.playing) {
      throw StateError('not playing');
    }
    if (!legalPlays(turn).contains(card)) {
      throw ArgumentError('illegal card $card for seat $turn');
    }
    hands[turn].remove(card);
    if (isLayout) {
      final i = card.suit.index;
      if (card.rank == 11) {
        low[i] = 11;
        high[i] = 11;
      } else if (card.rank < low[i]) {
        low[i] = card.rank;
      } else {
        high[i] = card.rank;
      }
      if (hands[turn].isEmpty) finished.add(turn);
      _advanceLayout();
      return false;
    }
    trick.add(TrickPlay(turn, card));
    if (trick.length < 4) {
      turn = (turn + 1) % 4;
      return false;
    }
    final winner = trickWinnerSeat(trick, null);
    for (final p in trick) {
      taken[winner].add(p.card);
    }
    tricksWon[winner] = tricksWon[winner] + 1;
    lastTrick = List<TrickPlay>.from(trick);
    lastTrickWinner = winner;
    trick = <TrickPlay>[];
    turn = winner;
    if (hands[0].isEmpty) _finishDeal();
    return true;
  }

  void _advanceLayout() {
    if (finished.length >= 3) {
      for (var seat = 0; seat < 4; seat++) {
        if (!finished.contains(seat)) {
          finished.add(seat);
          break;
        }
      }
      _finishDeal();
      return;
    }
    var next = (turn + 1) % 4;
    while (finished.contains(next)) {
      next = (next + 1) % 4;
    }
    turn = next;
  }

  void _finishDeal() {
    final chosen = contract!;
    final scores = chosen == TrixContract.trix
        ? trixLayoutScores(finished)
        : trixPenaltyScores(chosen, taken, tricksWon);
    for (var i = 0; i < 4; i++) {
      totals[i] = totals[i] + scores[i];
    }
    lastDealScores = scores;
    phase = TrixPhase.dealOver;
  }

  void nextDeal() {
    if (phase != TrixPhase.dealOver) {
      throw StateError('deal is not over');
    }
    dealIndex++;
    if (dealIndex >= trixDeals) {
      phase = TrixPhase.gameOver;
      return;
    }
    _startDeal();
  }

  // Seats with the highest total once the game is over.
  List<int> winners() {
    var best = totals[0];
    for (final t in totals) {
      if (t > best) best = t;
    }
    final result = <int>[];
    for (var i = 0; i < 4; i++) {
      if (totals[i] == best) result.add(i);
    }
    return result;
  }
}

// ---------------------------------------------------------------- bots

// Always returns one of [available].
TrixContract trixBotChooseContract(
  List<PlayingCard> hand,
  List<TrixContract> available,
) {
  final hearts = hand.where((c) => c.suit == Suit.hearts).length;
  final hasKingOfHearts =
      hand.any((c) => c.suit == Suit.hearts && c.rank == 13);
  final queens = hand.where((c) => c.rank == 12).length;
  final diamonds = hand.where((c) => c.suit == Suit.diamonds).length;
  final bigCards = hand.where((c) => c.rank >= 13).length;
  final jacks = hand.where((c) => c.rank == 11).length;
  final middle = hand.where((c) => c.rank >= 9 && c.rank <= 13).length;

  var best = available.first;
  var bestFit = -1000.0;
  for (final c in available) {
    var fit = 0.0;
    switch (c) {
      case TrixContract.kingOfHearts:
        fit = hasKingOfHearts ? (hearts >= 5 ? 2.0 : -4.0) : 1.0;
      case TrixContract.queens:
        fit = 2.5 - 2.0 * queens;
      case TrixContract.diamonds:
        fit = 3.0 - 0.8 * diamonds;
      case TrixContract.collections:
        fit = 3.0 - 0.9 * bigCards;
      case TrixContract.trix:
        fit = 0.9 * jacks + 0.2 * middle;
    }
    if (fit > bestFit) {
      bestFit = fit;
      best = c;
    }
  }
  return best;
}

// Always returns one of game.legalPlays(seat). For the layout game the caller
// must check game.currentMustPass first.
PlayingCard trixBotPlay(TrixGame game, int seat) {
  final legal = game.legalPlays(seat);
  if (legal.isEmpty) {
    throw StateError('no legal card');
  }
  if (legal.length == 1) return legal.first;
  final contract = game.contract!;
  final hand = game.hands[seat];

  if (contract == TrixContract.trix) {
    var best = legal.first;
    var bestValue = -1;
    for (final c in legal) {
      final sameSuit = hand.where((x) => x.suit == c.suit).length;
      final value = sameSuit * 10 + (c.rank - 11).abs();
      if (value > bestValue) {
        bestValue = value;
        best = c;
      }
    }
    return best;
  }

  if (game.trick.isEmpty) {
    var lowest = legal.first;
    for (final c in legal) {
      if (c.rank < lowest.rank) lowest = c;
    }
    return lowest;
  }

  final led = game.trick.first.card.suit;
  final hasLed = hand.any((c) => c.suit == led);
  if (hasLed) {
    var top = 0;
    for (final p in game.trick) {
      if (p.card.suit == led && p.card.rank > top) top = p.card.rank;
    }
    PlayingCard? highestBelow;
    PlayingCard lowest = legal.first;
    for (final c in legal) {
      if (c.rank < lowest.rank) lowest = c;
      if (c.rank < top) {
        if (highestBelow == null || c.rank > highestBelow.rank) {
          highestBelow = c;
        }
      }
    }
    if (highestBelow != null) return highestBelow;
    return lowest;
  }

  var dump = legal.first;
  var dumpValue = -1;
  for (final c in legal) {
    final value = trixCardPenalty(contract, c) * 100 + c.rank;
    if (value > dumpValue) {
      dumpValue = value;
      dump = c;
    }
  }
  return dump;
}
