import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zameel/services/home_snapshot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stories are account scoped and expired/private stories are excluded', () async {
    final future = DateTime.now().add(const Duration(hours: 2)).toIso8601String();
    final past = DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String();
    await HomeSnapshotService.save('alice', 'stories', [
      {'id': 'public', 'audience': 'public', 'expires_at': future},
      {'id': 'friends', 'audience': 'friends', 'expires_at': future},
      {'id': 'expired', 'audience': 'public', 'expires_at': past},
      {'id': 'missing_expiry', 'audience': 'public'},
    ]);
    expect((await HomeSnapshotService.read('alice', 'stories')).map((r) => r['id']), ['public']);
    expect(await HomeSnapshotService.read('bob', 'stories'), isEmpty);
  });

  test('only public non-hidden clips are persisted', () async {
    await HomeSnapshotService.save('alice', 'clips', [
      {'id': 'visible', 'audience': 'public', 'is_hidden': false},
      {'id': 'hidden', 'audience': 'public', 'is_hidden': true},
      {'id': 'private', 'audience': 'private'},
    ]);
    expect((await HomeSnapshotService.read('alice', 'clips')).map((r) => r['id']), ['visible']);
  });

  test('an advertisement must be published, undeleted and unexpired', () async {
    final future = DateTime.now().add(const Duration(days: 1)).toIso8601String();
    await HomeSnapshotService.save('alice', 'ads', [
      {'id': 'live', 'status': 'published', 'expires_at': future},
      {'id': 'draft', 'status': 'draft', 'expires_at': future},
      {'id': 'deleted', 'status': 'published', 'expires_at': future, 'deleted_at': future},
      {'id': 'unknown', 'status': 'published'},
    ]);
    expect((await HomeSnapshotService.read('alice', 'ads')).map((r) => r['id']), ['live']);
  });

  test('expired saved data is removed even when its items have later expiry', () async {
    SharedPreferences.setMockInitialValues({
      'zameel_home_v123_alice_clips': jsonEncode({
        'saved_at': DateTime.now().subtract(const Duration(hours: 7)).toIso8601String(),
        'rows': [{'id': 'old', 'audience': 'public'}],
      }),
    });
    expect(await HomeSnapshotService.read('alice', 'clips'), isEmpty);
  });

  test('successful empty refresh removes stale items and logout clears sections', () async {
    await HomeSnapshotService.save('alice', 'clips', [{'id': 'x', 'audience': 'public'}]);
    await HomeSnapshotService.save('alice', 'clips', []);
    expect(await HomeSnapshotService.read('alice', 'clips'), isEmpty);
    await HomeSnapshotService.save('alice', 'profile', [{'onboarding_complete': true}]);
    await HomeSnapshotService.clear('alice');
    expect(await HomeSnapshotService.read('alice', 'profile'), isEmpty);
  });
}
