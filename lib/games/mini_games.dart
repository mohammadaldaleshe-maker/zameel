// Rock-paper-scissors, dice and tic-tac-toe logic. Pure Dart, no Flutter.
import 'dart:math';

// ------------------------------------------------ rock paper scissors

enum RpsMove { rock, paper, scissors }

// 0 = draw, 1 = [a] wins, 2 = [b] wins.
int rpsOutcome(RpsMove a, RpsMove b) {
  if (a == b) return 0;
  final aWins = (a == RpsMove.rock && b == RpsMove.scissors) ||
      (a == RpsMove.scissors && b == RpsMove.paper) ||
      (a == RpsMove.paper && b == RpsMove.rock);
  return aWins ? 1 : 2;
}

RpsMove rpsBotMove(Random rng) => RpsMove.values[rng.nextInt(3)];

// ------------------------------------------------------------- dice

int rollDie(Random rng) => rng.nextInt(6) + 1;

List<int> rollDice(Random rng, int count) {
  final result = <int>[];
  for (var i = 0; i < count; i++) {
    result.add(rollDie(rng));
  }
  return result;
}

int diceTotal(List<int> dice) {
  var total = 0;
  for (final d in dice) {
    total += d;
  }
  return total;
}

// ------------------------------------------------------ tic-tac-toe
// Board cells: 0 empty, 1 = X, 2 = O. Index = row * 3 + column.

const List<List<int>> tttLines = <List<int>>[
  <int>[0, 1, 2],
  <int>[3, 4, 5],
  <int>[6, 7, 8],
  <int>[0, 3, 6],
  <int>[1, 4, 7],
  <int>[2, 5, 8],
  <int>[0, 4, 8],
  <int>[2, 4, 6],
];

// 0 when nobody has three in a row, otherwise 1 or 2.
int tttWinner(List<int> board) {
  for (final line in tttLines) {
    final a = board[line[0]];
    if (a != 0 && a == board[line[1]] && a == board[line[2]]) return a;
  }
  return 0;
}

bool tttFull(List<int> board) => !board.contains(0);

List<int> tttEmptyCells(List<int> board) {
  final cells = <int>[];
  for (var i = 0; i < 9; i++) {
    if (board[i] == 0) cells.add(i);
  }
  return cells;
}

int _tttOther(int player) => player == 1 ? 2 : 1;

// Score from the point of view of [me]; faster wins and slower losses are
// preferred.
int _tttMinimax(List<int> board, int turn, int me, int depth) {
  final winner = tttWinner(board);
  if (winner == me) return 10 - depth;
  if (winner != 0) return depth - 10;
  if (tttFull(board)) return 0;
  var best = turn == me ? -100 : 100;
  for (var i = 0; i < 9; i++) {
    if (board[i] != 0) continue;
    board[i] = turn;
    final score = _tttMinimax(board, _tttOther(turn), me, depth + 1);
    board[i] = 0;
    if (turn == me) {
      if (score > best) best = score;
    } else {
      if (score < best) best = score;
    }
  }
  return best;
}

// Picks a cell for [player] (1 or 2). The board must have an empty cell.
// level 0 = random, 1 = wins/blocks then random, 2 = perfect play.
int tttBestMove(List<int> board, int player, int level, Random rng) {
  final empty = tttEmptyCells(board);
  if (empty.isEmpty) {
    throw StateError('board is full');
  }
  if (level <= 0) return empty[rng.nextInt(empty.length)];

  final work = List<int>.from(board);
  if (level == 1) {
    for (final i in empty) {
      work[i] = player;
      final wins = tttWinner(work) == player;
      work[i] = 0;
      if (wins) return i;
    }
    final opponent = _tttOther(player);
    for (final i in empty) {
      work[i] = opponent;
      final wins = tttWinner(work) == opponent;
      work[i] = 0;
      if (wins) return i;
    }
    if (work[4] == 0) return 4;
    return empty[rng.nextInt(empty.length)];
  }

  // On an empty board every corner or the centre is already optimal; this
  // avoids a full search of the whole game tree for the first move.
  if (empty.length == 9) {
    const openers = <int>[0, 2, 4, 6, 8];
    return openers[rng.nextInt(openers.length)];
  }

  var bestScore = -1000;
  var bestMoves = <int>[];
  for (final i in empty) {
    work[i] = player;
    final score = _tttMinimax(work, _tttOther(player), player, 1);
    work[i] = 0;
    if (score > bestScore) {
      bestScore = score;
      bestMoves = <int>[i];
    } else if (score == bestScore) {
      bestMoves.add(i);
    }
  }
  return bestMoves[rng.nextInt(bestMoves.length)];
}
