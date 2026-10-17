import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/games/snakes_ladders.dart';
import 'package:zameel/screens/games/bot_personas.dart';

void main() {
  group('snakes and ladders board', () {
    test('every snake slides down and every ladder climbs up', () {
      slLadders.forEach((foot, top) {
        expect(top, greaterThan(foot));
        expect(top, lessThan(slBoardSize));
      });
      slSnakes.forEach((head, tail) {
        expect(tail, lessThan(head));
        expect(tail, greaterThan(1));
      });
    });

    test('no square is both a snake head and a ladder foot, and no chain', () {
      for (final foot in slLadders.keys) {
        expect(slSnakes.containsKey(foot), isFalse);
      }
      for (final top in slLadders.values) {
        expect(slSnakes.containsKey(top), isFalse);
        expect(slLadders.containsKey(top), isFalse);
      }
      for (final tail in slSnakes.values) {
        expect(slSnakes.containsKey(tail), isFalse);
        expect(slLadders.containsKey(tail), isFalse);
      }
      expect(slSnakes.containsKey(slBoardSize), isFalse);
    });

    test('cells follow the back-and-forth numbering', () {
      expect(slCell(1), (col: 0, row: 0));
      expect(slCell(10), (col: 9, row: 0));
      expect(slCell(11), (col: 9, row: 1));
      expect(slCell(20), (col: 0, row: 1));
      expect(slCell(100), (col: 0, row: 9));
      final seen = <String>{};
      for (var s = 1; s <= 100; s++) {
        final c = slCell(s);
        expect(seen.add('${c.col},${c.row}'), isTrue);
      }
    });
  });

  group('snakes and ladders rules', () {
    test('a ladder climbs and the turn passes on', () {
      final game = SnakesLaddersGame();
      game.positions[0] = 1;
      final move = game.play(3); // 1 + 3 = 4 -> ladder to 14
      expect(move.landed, 4);
      expect(move.to, 14);
      expect(move.climbed, isTrue);
      expect(game.positions[0], 14);
      expect(game.turn, 1);
    });

    test('a snake slides down', () {
      final game = SnakesLaddersGame();
      game.positions[0] = 12;
      final move = game.play(5); // 17 -> snake to 7
      expect(move.slid, isTrue);
      expect(game.positions[0], 7);
    });

    test('a six gives an extra turn', () {
      final game = SnakesLaddersGame();
      final move = game.play(6);
      expect(move.extraTurn, isTrue);
      expect(game.turn, 0);
      game.play(2);
      expect(game.turn, 1);
    });

    test('the last square needs an exact roll', () {
      final game = SnakesLaddersGame();
      game.positions[0] = 98;
      final blocked = game.play(5);
      expect(blocked.blocked, isTrue);
      expect(game.positions[0], 98);
      expect(game.isOver, isFalse);
      game.positions[1] = 1;
      game.play(1); // player 1 moves, turn returns to player 0
      expect(game.turn, 0);
      final win = game.play(2);
      expect(win.won, isTrue);
      expect(game.winner, 0);
      expect(game.isOver, isTrue);
      expect(() => game.play(1), throwsStateError);
    });

    test('a winning six does not grant another turn', () {
      final game = SnakesLaddersGame();
      game.positions[1] = 94;
      game.turn = 1;
      final win = game.play(6);
      expect(win.won, isTrue);
      expect(win.extraTurn, isFalse);
    });

    test('rejects a die value outside 1..6', () {
      final game = SnakesLaddersGame();
      expect(() => game.play(0), throwsArgumentError);
      expect(() => game.play(7), throwsArgumentError);
    });

    test('random games always finish with a legal winner', () {
      for (var seed = 0; seed < 200; seed++) {
        final rng = Random(seed);
        final game = SnakesLaddersGame();
        var steps = 0;
        while (!game.isOver) {
          game.rollRandom(rng);
          steps++;
          expect(steps, lessThan(5000));
          for (final p in game.positions) {
            expect(p, inInclusiveRange(0, slBoardSize));
          }
        }
        expect(game.positions[game.winner], slBoardSize);
      }
    });
  });

  group('computer players', () {
    test('there are men and women with Arabic names', () {
      expect(kBotPersonas.where((p) => p.female).length, greaterThanOrEqualTo(3));
      expect(kBotPersonas.where((p) => !p.female).length, greaterThanOrEqualTo(3));
      for (final p in kBotPersonas) {
        expect(RegExp(r'^[\u0600-\u06FF]+$').hasMatch(p.nameAr), isTrue);
      }
    });

    test('a drawn cast has distinct players for each seat', () {
      final cast = BotCast.draw(const <int>[1, 2, 3], random: Random(7));
      final names = <String>{
        for (final seat in const <int>[1, 2, 3]) cast.at(seat)!.nameAr,
      };
      expect(names.length, 3);
      expect(cast.at(0), isNull);
    });
  });
}
