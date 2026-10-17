// Snakes and ladders rules. Pure Dart, no Flutter imports.
//
// A 10 x 10 board numbered 1..100. Landing on the foot of a ladder climbs to
// its top, landing on a snake's head slides down to its tail. A roll of six
// gives an extra turn. The last square must be reached with an exact roll; a
// roll that would pass 100 leaves the token where it is.
import 'dart:math';

const int slBoardSize = 100;

// foot -> top
const Map<int, int> slLadders = <int, int>{
  4: 14,
  9: 31,
  20: 38,
  28: 84,
  40: 59,
  51: 67,
  63: 81,
  71: 91,
};

// head -> tail
const Map<int, int> slSnakes = <int, int>{
  17: 7,
  54: 34,
  62: 19,
  64: 60,
  87: 24,
  93: 73,
  95: 75,
  99: 78,
};

// Where a token ends after landing on [square]: follows a ladder or a snake.
int slResolve(int square) => slLadders[square] ?? slSnakes[square] ?? square;

// What one roll did.
class SlMove {
  const SlMove({
    required this.player,
    required this.roll,
    required this.from,
    required this.landed,
    required this.to,
    required this.extraTurn,
    required this.won,
  });

  final int player;
  final int roll;
  final int from;
  // Square reached by the dice before any snake or ladder.
  final int landed;
  // Final square after the snake or ladder.
  final int to;
  final bool extraTurn;
  final bool won;

  bool get climbed => to > landed;
  bool get slid => to < landed;
  bool get blocked => landed == from;
}

class SnakesLaddersGame {
  SnakesLaddersGame({this.players = 2})
      : positions = List<int>.filled(players, 0);

  final int players;
  // 0 means "not on the board yet".
  final List<int> positions;
  int turn = 0;
  int winner = -1;

  bool get isOver => winner >= 0;

  // Plays one turn for the current player with the given die value (1..6).
  SlMove play(int roll) {
    if (isOver) throw StateError('game is over');
    if (roll < 1 || roll > 6) throw ArgumentError.value(roll, 'roll');
    final player = turn;
    final from = positions[player];
    var landed = from + roll;
    if (landed > slBoardSize) landed = from;
    final to = landed == from ? from : slResolve(landed);
    positions[player] = to;
    final won = to == slBoardSize;
    final extra = roll == 6 && !won;
    if (won) {
      winner = player;
    } else if (!extra) {
      turn = (turn + 1) % players;
    }
    return SlMove(
      player: player,
      roll: roll,
      from: from,
      landed: landed,
      to: to,
      extraTurn: extra,
      won: won,
    );
  }

  // Convenience used by the phone player.
  SlMove rollRandom(Random rng) => play(rng.nextInt(6) + 1);
}

// Board square (1..100) to its grid cell. Row 0 is the bottom row and the rows
// snake back and forth like a real board. Returns (column, row).
({int col, int row}) slCell(int square) {
  final index = square - 1;
  final row = index ~/ 10;
  final inRow = index % 10;
  final col = row.isEven ? inRow : 9 - inRow;
  return (col: col, row: row);
}
