import 'dart:io';
import 'package:zameel/services/post_video_reference156.dart';

void main() {
  void check(Map<String, dynamic> post, String expected) {
    final actual = postVideoReference156(post);
    if (actual != expected) throw StateError('Wrong attached video: $actual');
  }

  check({}, '');
  check({'video_url': null}, '');
  check({'video_url': '  '}, '');
  check({'video_url': 123}, '');
  check({'video_url': 'https://fixture.test/yamal.mp4'},
      'https://fixture.test/yamal.mp4');
  check({'videoUrl': 'https://fixture.test/yamal.mp4'},
      'https://fixture.test/yamal.mp4');
  check({'video_url': '', 'videoUrl': 'https://fixture.test/yamal.mp4'},
      'https://fixture.test/yamal.mp4');
  check({
    'media_items': [
      {'type': 'image', 'url': 'photo.jpg'},
      {'type': 'video', 'url': ' https://fixture.test/yamal.mp4 '}
    ]
  }, 'https://fixture.test/yamal.mp4');
  check({
    'video_url': 'stale.mp4',
    'media_items': [
      {'type': 'video', 'url': 'original.mp4'}
    ]
  }, 'original.mp4');
  check({
    'media_items': [
      {'type': 'video', 'url': null}
    ]
  }, '');
  check({'video_url': 'zameel-private://bucket?path=owner%2Freal.mp4'},
      'zameel-private://bucket?path=owner%2Freal.mp4');
  check({
    'media_index': 1,
    'video_url': 'second.mp4',
    'media_items': [
      {'type': 'video', 'url': 'first.mp4'},
      {'type': 'video', 'url': 'second.mp4'}
    ]
  }, 'second.mp4');
  check({
    'media_index': 1,
    'video_url': null,
    'media_items': [
      {'type': 'video', 'url': 'first.mp4'}
    ]
  }, '');
  final source = File('lib/features/posts_media.dart').readAsStringSync();
  if (source.contains('bee.mp4'))
    throw StateError('Sample fallback still present');
  if (!source.contains('postVideoReference156(widget.post)'))
    throw StateError('Player does not use attached-media resolver');
  print(
      'PASS: 13 media-reference cases; absent media never selects a sample; original ordered and legacy/private video references preserved.');
}
