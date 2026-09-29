import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zameel/services/feed_snapshot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a snapshot is account scoped and never stores non-public posts', () async {
    SharedPreferences.setMockInitialValues({});
    await FeedSnapshotService.save('student-a', [
      {'id': 'public', 'audience': 'public', 'content': 'hello'},
      {'id': 'friends', 'audience': 'friends', 'content': 'secret'},
      {'id': 'private', 'audience': 'private', 'content': 'secret'},
    ]);
    expect((await FeedSnapshotService.read('student-a')).map((p) => p['id']),
        ['public']);
    expect(await FeedSnapshotService.read('student-b'), isEmpty);
    await FeedSnapshotService.clear('student-a');
    expect(await FeedSnapshotService.read('student-a'), isEmpty);
  });

  test('a snapshot older than six hours is ignored', () async {
    SharedPreferences.setMockInitialValues({
      'zameel_public_feed_v1_student-a': jsonEncode({
        'saved_at': DateTime.now().subtract(const Duration(hours: 7)).toIso8601String(),
        'posts': [
          {'id': 'old', 'audience': 'public'}
        ],
      }),
    });
    expect(await FeedSnapshotService.read('student-a'), isEmpty);
  });
}
