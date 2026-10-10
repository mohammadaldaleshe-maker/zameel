import '../lib/services/sponsored_feed.dart';

void check(bool value, String reason) {
  if (!value) throw StateError(reason);
}

void main() {
  final ordinary = [
    for (var i = 0; i < 3000; i++)
      {'id': 'p$i', 'audience': i.isEven ? 'friends' : 'public'}
  ];
  final ads = [
    for (var i = 0; i < 500; i++) {'id': 'a$i'}
  ];
  final feed = arrangeSponsoredFeed(ordinary, ads, 'viewer');
  check(feed.length == 3500, 'one placement after every six ordinary posts');
  for (var i = 0; i < 500; i++) {
    check(feed[i * 7 + 6]['id'] == 'a$i', 'server rotation preserved');
  }
  final duplicates = arrangeSponsoredFeed([
    {'id': 'p'},
    {'id': 'p'},
    for (var i = 1; i < 6; i++) {'id': 'p$i'}
  ], [
    {'id': 'a'},
    {'id': 'a'}
  ], null);
  check(duplicates.length == 7, 'duplicates do not add placements');
  check(arrangeSponsoredFeed(ordinary, [], null).length == 3000,
      'ordinary feed preserved without promotions');
  check(arrangeSponsoredFeed(ordinary.take(5).toList(), ads, null).length == 5,
      'no premature advertisement');
  print(
      'PASS: 500 campaign placements, six-post spacing, private rows, duplicates, server order and empty candidates.');
}
