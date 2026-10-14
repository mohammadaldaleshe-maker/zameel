import 'package:zameel/services/post_presentation157.dart';

void main() {
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  check(
      jordanPostDate157('2026-10-13T04:12:45.218695+00:00') ==
          '13/10/2026 · 07:12',
      'Jordan UTC+3');
  check(jordanPostDate157('2026-10-13T07:12:45+03:00') == '13/10/2026 · 07:12',
      'Offset preserved');
  check(jordanPostDate157(null).isEmpty && jordanPostDate157('null').isEmpty,
      'Null suppressed');
  check(
      postMetadata157(
              {'department_ar': null, 'created_at': '2026-10-13T04:12:45Z'},
              true, now: DateTime.parse('2026-10-13T04:13:45Z')) ==
          'قبل دقيقة',
      'No null or separator');
  check(
      postMetadata157({
            'department_ar': 'الهندسة',
            'created_at': '2026-10-13T04:12:45Z'
          }, true, now: DateTime.parse('2026-10-13T04:13:45Z')) ==
          'الهندسة · قبل دقيقة',
      'Readable metadata');
  check(
      !completedMediaPost157({
        'upload_state156': 'ready',
        'type': 'video',
        'video_url': null,
        'media_items': []
      }),
      'Ready without video cannot complete');
  check(
      !completedMediaPost157({
        'upload_state156': 'pending',
        'type': 'video',
        'video_url': 'https://example.test/a.mp4'
      }),
      'Pending cannot complete');
  check(
      completedMediaPost157({
        'upload_state156': 'ready',
        'type': 'video',
        'media_items': [
          {'type': 'video', 'url': 'private://object'}
        ]
      }),
      'Private reference preserved');
  check(completedMediaPost157({'upload_state156': 'ready', 'type': 'text'}),
      'Text works');
  check(
      !completedMediaPost157({
        'upload_state156': 'ready',
        'type': 'video',
        'video_url': 'uploading://unfinished'
      }),
      'Placeholder excluded');
  print(
      'PASS: Jordan timestamps, null suppression, readable metadata, complete media and text posts, pending/placeholder rejection.');
}
