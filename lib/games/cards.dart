// Pure Dart playing-card helpers shared by the card games. No Flutter imports.
import 'dart:math';

enum Suit { spades, hearts, diamonds, clubs }

const List<Suit> allSuits = <Suit>[
  Suit.spades,
  Suit.hearts,
  Suit.diamonds,
  Suit.clubs,
];

String suitSymbol(Suit suit) {
  return switch (suit) {
    Suit.spades => '♠',
    Suit.hearts => '♥',
    Suit.diamonds => '♦',
    Suit.clubs => '♣',
  };
}

bool isRedSuit(Suit suit) => suit == Suit.hearts || suit == Suit.diamonds;

String rankLabel(int rank) {
  if (rank == 11) return 'J';
  if (rank == 12) return 'Q';
  if (rank == 13) return 'K';
  if (rank == 14) return 'A';
  return '$rank';
}

// Rank is 2..14 where 11 is Jack, 12 Queen, 13 King and 14 Ace.
class PlayingCard {
  const PlayingCard(this.suit, this.rank);

  final Suit suit;
  final int rank;

  bool get isJack => rank == 11;

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => suit.index * 100 + rank;

  @override
  String toString() => '${suitSymbol(suit)}${rankLabel(rank)}';
}

// One card played into a trick by a seat (0..3).
class TrickPlay {
  const TrickPlay(this.seat, this.card);

  final int seat;
  final PlayingCard card;
}

List<PlayingCard> newDeck() {
  final deck = <PlayingCard>[];
  for (final suit in allSuits) {
    for (var rank = 2; rank <= 14; rank++) {
      deck.add(PlayingCard(suit, rank));
    }
  }
  return deck;
}

void sortHand(List<PlayingCard> hand) {
  hand.sort((a, b) {
    if (a.suit != b.suit) return a.suit.index - b.suit.index;
    return b.rank - a.rank;
  });
}

// Shuffles a fresh 52-card deck and deals four sorted hands of 13 cards.
List<List<PlayingCard>> dealHands(Random rng) {
  final deck = newDeck();
  deck.shuffle(rng);
  final hands = <List<PlayingCard>>[];
  for (var seat = 0; seat < 4; seat++) {
    final hand = deck.sublist(seat * 13, seat * 13 + 13);
    sortHand(hand);
    hands.add(hand);
  }
  return hands;
}

// True when [card] beats the currently best card of a trick.
// [led] is the suit that was led; [trump] may be null (no trump).
bool trickBeats(PlayingCard card, PlayingCard best, Suit led, Suit? trump) {
  final cardTrump = trump != null && card.suit == trump;
  final bestTrump = trump != null && best.suit == trump;
  if (cardTrump && !bestTrump) return true;
  if (!cardTrump && bestTrump) return false;
  if (card.suit == best.suit) return card.rank > best.rank;
  return false;
}

// Seat that wins a complete (or partial) trick. The trick must not be empty.
int trickWinnerSeat(List<TrickPlay> trick, Suit? trump) {
  final led = trick.first.card.suit;
  var best = trick.first;
  for (var i = 1; i < trick.length; i++) {
    final play = trick[i];
    if (trickBeats(play.card, best.card, led, trump)) best = play;
  }
  return best.seat;
}
