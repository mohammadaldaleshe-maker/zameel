// Tarneeb (Levantine rules), pure Dart. No Flutter imports.
//
// Seats: 0 = you (south), 1 = left opponent (west), 2 = your partner (north),
// 3 = right opponent (east). Teams: seats 0 and 2 are team 0, seats 1 and 3
// are team 1. Play goes 0 -> 1 -> 2 -> 3 -> 0.
import 'dart:math';

import 'cards.dart';

enum TarneebPhase { bidding, chooseTrump, playing, handOver, gameOver }

// Score change of each team for one finished hand.
// The bidding team scores its tricks when it reaches the bid and loses the bid
// otherwise. The other team always scores the tricks it won.
List<int> tarneebHandDelta(int bidTeam, int bid, List<int> tricksWon) {
  final other = 1 - bidTeam;
  final delta = <int>[0, 0];
  if (tricksWon[bidTeam] >= bid) {
    delta[bidTeam] = tricksWon[bidTeam];
  } else {
    delta[bidTeam] = -bid;
  }
  delta[other] = tricksWon[other];
  return delta;
}

class TarneebGame {
  TarneebGame({Random? random, this.targetScore = 31, int firstDealer = 3})
      : rng = random ?? Random() {
    dealer = firstDealer;
    _startHand();
  }

  final Random rng;
  final int targetScore;

  List<List<PlayingCard>> hands = <List<PlayingCard>>[];
  int dealer = 3;
  TarneebPhase phase = TarneebPhase.bidding;
  List<int> bids = <int>[];
  int highBid = 0;
  int highBidder = -1;
  Suit? trump;
  int turn = 0;
  List<TrickPlay> trick = <TrickPlay>[];
  List<TrickPlay> lastTrick = <TrickPlay>[];
  int lastTrickWinner = -1;
  List<int> tricksWon = <int>[0, 0];
  List<int> score = <int>[0, 0];
  List<int> lastHandDelta = <int>[0, 0];
  int handNumber = 1;
  int winnerTeam = -1;

  void _startHand() {
    hands = dealHands(rng);
    bids = <int>[];
    highBid = 0;
    highBidder = -1;
    trump = null;
    trick = <TrickPlay>[];
    lastTrick = <TrickPlay>[];
    lastTrickWinner = -1;
    tricksWon = <int>[0, 0];
    phase = TarneebPhase.bidding;
    turn = (dealer + 1) % 4;
  }

  // 0 means pass. The last bidder cannot pass when everybody else passed.
  List<int> legalBids() {
    final result = <int>[];
    final forced = bids.length == 3 && highBid == 0;
    if (!forced) result.add(0);
    final first = highBid < 7 ? 7 : highBid + 1;
    for (var b = first; b <= 13; b++) {
      result.add(b);
    }
    return result;
  }

  void placeBid(int bid) {
    if (phase != TarneebPhase.bidding) {
      throw StateError('not bidding');
    }
    if (!legalBids().contains(bid)) {
      throw ArgumentError('illegal bid $bid');
    }
    bids.add(bid);
    if (bid > 0) {
      highBid = bid;
      highBidder = turn;
    }
    if (bids.length == 4) {
      phase = TarneebPhase.chooseTrump;
      turn = highBidder;
    } else {
      turn = (turn + 1) % 4;
    }
  }

  void chooseTrump(Suit suit) {
    if (phase != TarneebPhase.chooseTrump) {
      throw StateError('not choosing trump');
    }
    trump = suit;
    phase = TarneebPhase.playing;
    turn = highBidder;
    trick = <TrickPlay>[];
  }

  // Follow the led suit when possible; otherwise any card.
  List<PlayingCard> legalPlays(int seat) {
    final hand = hands[seat];
    if (trick.isEmpty) return List<PlayingCard>.from(hand);
    final led = trick.first.card.suit;
    final follow = hand.where((c) => c.suit == led).toList();
    if (follow.isNotEmpty) return follow;
    return List<PlayingCard>.from(hand);
  }

  // Plays a card for the seat whose turn it is. Returns true when this card
  // completed a trick.
  bool play(PlayingCard card) {
    if (phase != TarneebPhase.playing) {
      throw StateError('not playing');
    }
    if (!legalPlays(turn).contains(card)) {
      throw ArgumentError('illegal card $card for seat $turn');
    }
    hands[turn].remove(card);
    trick.add(TrickPlay(turn, card));
    if (trick.length < 4) {
      turn = (turn + 1) % 4;
      return false;
    }
    final winner = trickWinnerSeat(trick, trump);
    lastTrick = List<TrickPlay>.from(trick);
    lastTrickWinner = winner;
    tricksWon[winner % 2] = tricksWon[winner % 2] + 1;
    trick = <TrickPlay>[];
    turn = winner;
    if (hands[0].isEmpty) _finishHand();
    return true;
  }

  void _finishHand() {
    final bidTeam = highBidder % 2;
    final delta = tarneebHandDelta(bidTeam, highBid, tricksWon);
    lastHandDelta = delta;
    score[0] = score[0] + delta[0];
    score[1] = score[1] + delta[1];
    final a = score[0] >= targetScore;
    final b = score[1] >= targetScore;
    winnerTeam = -1;
    if (a && b) {
      if (score[0] != score[1]) winnerTeam = score[0] > score[1] ? 0 : 1;
    } else if (a) {
      winnerTeam = 0;
    } else if (b) {
      winnerTeam = 1;
    }
    phase = winnerTeam >= 0 ? TarneebPhase.gameOver : TarneebPhase.handOver;
  }

  void nextHand() {
    if (phase != TarneebPhase.handOver) {
      throw StateError('hand is not over');
    }
    dealer = (dealer + 1) % 4;
    handNumber++;
    _startHand();
  }
}

// ---------------------------------------------------------------- bots

double tarneebHandStrength(List<PlayingCard> hand) {
  var total = 0.0;
  var longest = 0;
  for (final suit in allSuits) {
    final cards = hand.where((c) => c.suit == suit).toList();
    final len = cards.length;
    if (len > longest) longest = len;
    for (final c in cards) {
      if (c.rank == 14) {
        total += 1.0;
      } else if (c.rank == 13) {
        total += len >= 2 ? 0.75 : 0.3;
      } else if (c.rank == 12) {
        total += len >= 3 ? 0.4 : 0.1;
      }
    }
  }
  if (longest > 4) total += (longest - 4) * 0.8;
  return total;
}

// Always returns one of [legal].
int tarneebBotBid(List<PlayingCard> hand, List<int> legal) {
  if (!legal.contains(0)) return legal.first;
  final raises = legal.where((b) => b > 0).toList();
  if (raises.isEmpty) return 0;
  final target = (tarneebHandStrength(hand) + 3.0).floor();
  final lowest = raises.first;
  if (lowest <= target) return lowest;
  return 0;
}

Suit tarneebBotTrump(List<PlayingCard> hand) {
  var bestSuit = allSuits.first;
  var bestScore = -1;
  for (final suit in allSuits) {
    var value = 0;
    for (final c in hand) {
      if (c.suit != suit) continue;
      value += 3;
      if (c.rank == 14) value += 4;
      if (c.rank == 13) value += 3;
      if (c.rank == 12) value += 2;
      if (c.rank == 11) value += 1;
    }
    if (value > bestScore) {
      bestScore = value;
      bestSuit = suit;
    }
  }
  return bestSuit;
}

PlayingCard _lowestCard(List<PlayingCard> cards, Suit? trump) {
  final plain = cards.where((c) => c.suit != trump).toList();
  final pool = plain.isNotEmpty ? plain : cards;
  var best = pool.first;
  for (final c in pool) {
    if (c.rank < best.rank) best = c;
  }
  return best;
}

// Always returns one of game.legalPlays(seat).
PlayingCard tarneebBotPlay(TarneebGame game, int seat) {
  final legal = game.legalPlays(seat);
  if (legal.length == 1) return legal.first;
  final trump = game.trump;

  if (game.trick.isEmpty) {
    for (final c in legal) {
      if (c.rank == 14 && c.suit != trump) return c;
    }
    return _lowestCard(legal, trump);
  }

  final led = game.trick.first.card.suit;
  final winnerSeat = trickWinnerSeat(game.trick, trump);
  final winnerCard =
      game.trick.firstWhere((p) => p.seat == winnerSeat).card;
  if (winnerSeat % 2 == seat % 2) {
    return _lowestCard(legal, trump);
  }
  final winners =
      legal.where((c) => trickBeats(c, winnerCard, led, trump)).toList();
  if (winners.isEmpty) return _lowestCard(legal, trump);
  var best = winners.first;
  for (final c in winners) {
    final cTrump = c.suit == trump;
    final bTrump = best.suit == trump;
    if (cTrump && !bTrump) continue;
    if (!cTrump && bTrump) {
      best = c;
      continue;
    }
    if (c.rank < best.rank) best = c;
  }
  return best;
}
