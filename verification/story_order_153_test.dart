import 'package:zameel/services/story_order_service.dart';

void main() {
  final stories = <Map<String, dynamic>>[
    {
      'id': 'seen',
      'user_id': 'B',
      'viewed': true,
      'created_at': '2026-10-11T10:00:00Z'
    },
    {
      'id': 'old',
      'user_id': 'A',
      'viewed': false,
      'created_at': '2026-10-10T10:00:00Z'
    },
    {
      'id': 'new',
      'user_id': 'C',
      'viewed': false,
      'created_at': '2026-10-11T09:00:00Z'
    },
    {'id': 'mine', 'user_id': 'D', 'viewed': true, 'isMine': true},
  ];
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  final first = orderedStoryGroups(stories);
  check(first.map((g) => g.first['id']).join(',') == 'mine,new,old,seen',
      'unviewed/newest order');
  stories[2]['viewed'] = true;
  check(
      orderedStoryGroups(stories).map((g) => g.first['id']).join(',') ==
          'mine,old,seen,new',
      'viewed group moves to end');
  check(first[1].first['id'] == 'new', 'viewer snapshot retains order');
  check(stories.first['id'] == 'seen', 'source ordering is not mutated');
  check(orderedStoryGroups([]).isEmpty, 'empty stories');
  final partial = <Map<String, dynamic>>[
    {'user_id': 'P', 'viewed': true},
    {'user_id': 'P', 'viewed': false},
    {'user_id': 'Q', 'viewed': true}
  ];
  check(orderedStoryGroups(partial).first.length == 2,
      'partially unseen group remains together and first');
  print(
      'PASS: actual story ordering; unseen/newest/watched-last, partial groups, own tray, frozen viewer and empty list.');
}
