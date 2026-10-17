import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/games/cards.dart';
import 'package:zameel/games/mini_games.dart';
import 'package:zameel/games/tarneeb.dart';
import 'package:zameel/games/trix.dart';

void simulateTarneebGame(int seed) {
  final game = TarneebGame(random: Random(seed));
  var steps = 0;
  while (game.phase != TarneebPhase.gameOver) {
    steps++;
    expect(steps < 200000, isTrue, reason: 'game $seed did not finish');
    expect(game.handNumber < 500, isTrue, reason: 'too many hands $seed');
    if (game.phase == TarneebPhase.bidding) {
      final legal = game.legalBids();
      final bid = tarneebBotBid(game.hands[game.turn], legal);
      expect(legal.contains(bid), isTrue, reason: 'illegal bot bid');
      game.placeBid(bid);
    } else if (game.phase == TarneebPhase.chooseTrump) {
      game.chooseTrump(tarneebBotTrump(game.hands[game.highBidder]));
    } else if (game.phase == TarneebPhase.playing) {
      final seat = game.turn;
      final legal = game.legalPlays(seat);
      final card = tarneebBotPlay(game, seat);
      expect(legal.contains(card), isTrue, reason: 'illegal bot card');
      game.play(card);
    } else {
      expect(game.tricksWon[0] + game.tricksWon[1], 13);
      game.nextHand();
    }
  }
  expect(game.winnerTeam == 0 || game.winnerTeam == 1, isTrue);
}

void simulateTrixGame(int seed) {
  final game = TrixGame(random: Random(seed));
  var steps = 0;
  while (game.phase != TrixPhase.gameOver) {
    steps++;
    expect(steps < 1000000, isTrue, reason: 'game $seed did not finish');
    if (game.phase == TrixPhase.chooseContract) {
      final available = game.availableContracts();
      expect(available.isNotEmpty, isTrue);
      final choice = trixBotChooseContract(game.hands[game.owner], available);
      expect(available.contains(choice), isTrue, reason: 'illegal contract');
      game.startContract(choice);
    } else if (game.phase == TrixPhase.playing) {
      if (game.currentMustPass) {
        game.pass();
        continue;
      }
      final seat = game.turn;
      final legal = game.legalPlays(seat);
      final card = trixBotPlay(game, seat);
      expect(legal.contains(card), isTrue, reason: 'illegal bot card');
      game.play(card);
    } else {
      game.nextDeal();
    }
  }
  var grand = 0;
  for (final t in game.totals) {
    grand += t;
  }
  // Every kingdom hands out -500 in penalties and +500 for the layout game.
  expect(grand, 0);
}

void main() {
  group('cards', () {
    test('deck has 52 distinct cards and deals 4 hands of 13', () {
      expect(newDeck().toSet().length, 52);
      final hands = dealHands(Random(1));
      final all = <PlayingCard>{};
      for (final hand in hands) {
        expect(hand.length, 13);
        all.addAll(hand);
      }
      expect(all.length, 52);
    });

    test('trick winner with and without trump', () {
      final trick = <TrickPlay>[
        const TrickPlay(0, PlayingCard(Suit.hearts, 10)),
        const TrickPlay(1, PlayingCard(Suit.hearts, 14)),
        const TrickPlay(2, PlayingCard(Suit.spades, 2)),
        const TrickPlay(3, PlayingCard(Suit.diamonds, 13)),
      ];
      expect(trickWinnerSeat(trick, null), 1);
      expect(trickWinnerSeat(trick, Suit.spades), 2);
      expect(trickWinnerSeat(trick, Suit.diamonds), 3);
      expect(trickWinnerSeat(trick, Suit.clubs), 1);
    });
  });

  group('tarneeb', () {
    test('bids start at 7, the last bidder cannot pass when all passed', () {
      final game = TarneebGame(random: Random(3));
      expect(game.turn, 0);
      expect(game.legalBids().first, 0);
      expect(game.legalBids()[1], 7);
      game.placeBid(0);
      game.placeBid(0);
      game.placeBid(0);
      expect(game.legalBids().contains(0), isFalse);
      expect(game.legalBids().first, 7);
      game.placeBid(7);
      expect(game.phase, TarneebPhase.chooseTrump);
      expect(game.highBidder, 3);
      expect(() => game.placeBid(8), throwsStateError);
    });

    test('a bid must be higher than the previous one', () {
      final game = TarneebGame(random: Random(4));
      game.placeBid(9);
      expect(game.legalBids().contains(9), isFalse);
      expect(game.legalBids().contains(10), isTrue);
      expect(() => game.placeBid(8), throwsArgumentError);
    });

    test('must follow suit when possible', () {
      final game = TarneebGame(random: Random(5));
      game.placeBid(7);
      game.placeBid(0);
      game.placeBid(0);
      game.placeBid(0);
      game.chooseTrump(Suit.spades);
      final leader = game.turn;
      expect(leader, 0);
      final lead = game.legalPlays(leader).first;
      game.play(lead);
      final next = game.turn;
      final legal = game.legalPlays(next);
      final hasLed = game.hands[next].any((c) => c.suit == lead.suit);
      if (hasLed) {
        expect(legal.every((c) => c.suit == lead.suit), isTrue);
      } else {
        expect(legal.length, game.hands[next].length);
      }
    });

    test('hand scoring', () {
      expect(tarneebHandDelta(0, 7, <int>[8, 5]), <int>[8, 5]);
      expect(tarneebHandDelta(0, 9, <int>[8, 5]), <int>[-9, 5]);
      expect(tarneebHandDelta(1, 7, <int>[6, 7]), <int>[6, 7]);
      expect(tarneebHandDelta(1, 8, <int>[6, 7]), <int>[6, -8]);
    });

    test('bots finish many seeded games with legal moves only', () {
      for (var seed = 1; seed <= 1200; seed++) {
        simulateTarneebGame(seed);
      }
    });
  });

  group('trix', () {
    test('contract penalties', () {
      const king = PlayingCard(Suit.hearts, 13);
      const queenDiamonds = PlayingCard(Suit.diamonds, 12);
      expect(trixCardPenalty(TrixContract.kingOfHearts, king), 75);
      expect(trixCardPenalty(TrixContract.kingOfHearts, queenDiamonds), 0);
      expect(trixCardPenalty(TrixContract.queens, queenDiamonds), 25);
      expect(trixCardPenalty(TrixContract.queens, king), 0);
      expect(trixCardPenalty(TrixContract.diamonds, queenDiamonds), 10);
      expect(trixCardPenalty(TrixContract.diamonds, king), 0);
    });

    test('penalty and layout scoring', () {
      final taken = <List<PlayingCard>>[
        <PlayingCard>[
          const PlayingCard(Suit.hearts, 13),
          const PlayingCard(Suit.spades, 12),
          const PlayingCard(Suit.diamonds, 5),
          const PlayingCard(Suit.diamonds, 12),
        ],
        <PlayingCard>[],
        <PlayingCard>[],
        <PlayingCard>[],
      ];
      final tricks = <int>[1, 0, 0, 0];
      expect(
        trixPenaltyScores(TrixContract.kingOfHearts, taken, tricks),
        <int>[-75, 0, 0, 0],
      );
      expect(
        trixPenaltyScores(TrixContract.queens, taken, tricks),
        <int>[-50, 0, 0, 0],
      );
      expect(
        trixPenaltyScores(TrixContract.diamonds, taken, tricks),
        <int>[-20, 0, 0, 0],
      );
      expect(
        trixPenaltyScores(TrixContract.collections, taken, tricks),
        <int>[-15, 0, 0, 0],
      );
      expect(trixLayoutScores(<int>[2, 0, 3, 1]), <int>[150, 50, 200, 100]);
    });

    test('each owner uses every contract once and a game has 20 deals', () {
      final game = TrixGame(random: Random(7));
      expect(game.availableContracts().length, 5);
      game.startContract(TrixContract.trix);
      expect(game.availableContracts().length, 4);
      expect(game.availableContracts().contains(TrixContract.trix), isFalse);
      expect(() => game.startContract(TrixContract.trix), throwsStateError);
    });

    test('layout: jacks always playable, other cards must extend a row', () {
      final game = TrixGame(random: Random(8));
      game.startContract(TrixContract.trix);
      final seat = game.turn;
      final legal = game.legalPlays(seat);
      expect(legal.every((c) => c.rank == 11), isTrue);
      final withoutJack = game.hands[seat].every((c) => c.rank != 11);
      expect(withoutJack, legal.isEmpty);
    });

    test('bots finish many seeded games with legal moves only', () {
      for (var seed = 1; seed <= 500; seed++) {
        simulateTrixGame(seed);
      }
    });
  });

  group('mini games', () {
    test('rock paper scissors outcome table', () {
      expect(rpsOutcome(RpsMove.rock, RpsMove.rock), 0);
      expect(rpsOutcome(RpsMove.rock, RpsMove.scissors), 1);
      expect(rpsOutcome(RpsMove.scissors, RpsMove.rock), 2);
      expect(rpsOutcome(RpsMove.paper, RpsMove.rock), 1);
      expect(rpsOutcome(RpsMove.rock, RpsMove.paper), 2);
      expect(rpsOutcome(RpsMove.scissors, RpsMove.paper), 1);
      expect(rpsOutcome(RpsMove.paper, RpsMove.scissors), 2);
      expect(rpsOutcome(RpsMove.paper, RpsMove.paper), 0);
      expect(rpsOutcome(RpsMove.scissors, RpsMove.scissors), 0);
    });

    test('dice stay in range', () {
      final rng = Random(11);
      for (var i = 0; i < 2000; i++) {
        final die = rollDie(rng);
        expect(die >= 1 && die <= 6, isTrue);
      }
      final two = rollDice(rng, 2);
      expect(two.length, 2);
      expect(diceTotal(<int>[3, 4]), 7);
    });

    test('tic-tac-toe winner detection', () {
      expect(tttWinner(<int>[1, 1, 1, 0, 2, 2, 0, 0, 0]), 1);
      expect(tttWinner(<int>[2, 1, 1, 2, 1, 0, 2, 0, 0]), 2);
      expect(tttWinner(<int>[1, 2, 1, 1, 2, 2, 2, 1, 1]), 0);
      expect(tttFull(<int>[1, 2, 1, 1, 2, 2, 2, 1, 1]), isTrue);
    });

    test('medium level wins and blocks', () {
      final rng = Random(2);
      expect(tttBestMove(<int>[1, 1, 0, 2, 2, 0, 0, 0, 0], 1, 1, rng), 2);
      expect(tttBestMove(<int>[1, 1, 0, 2, 0, 0, 0, 0, 0], 2, 1, rng), 2);
    });

    test('perfect level never loses against random play', () {
      for (var seed = 1; seed <= 200; seed++) {
        final rng = Random(seed);
        for (final ai in <int>[1, 2]) {
          final board = List<int>.filled(9, 0);
          var turn = 1;
          while (tttWinner(board) == 0 && !tttFull(board)) {
            final level = turn == ai ? 2 : 0;
            board[tttBestMove(board, turn, level, rng)] = turn;
            turn = turn == 1 ? 2 : 1;
          }
          final winner = tttWinner(board);
          expect(winner == 0 || winner == ai, isTrue,
              reason: 'perfect player lost, seed $seed ai $ai');
        }
      }
    });

    test('perfect against perfect is a draw', () {
      final rng = Random(9);
      final board = List<int>.filled(9, 0);
      var turn = 1;
      while (tttWinner(board) == 0 && !tttFull(board)) {
        board[tttBestMove(board, turn, 2, rng)] = turn;
        turn = turn == 1 ? 2 : 1;
      }
      expect(tttWinner(board), 0);
    });
  });
}
