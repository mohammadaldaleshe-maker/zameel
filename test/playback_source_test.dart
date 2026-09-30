import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/services/playback_source.dart';

void main() {
  test('a disk hit starts offline without requesting a signed URL', () async {
    final result = await choosePlaybackSource('video',
      lookupCached: (_) async => '/cache/video.mp4',
      resolveRemote: (_) async => throw StateError('network must not be touched'),
    );
    expect(result.isLocal, isTrue);
    expect(result.value, '/cache/video.mp4');
  });
  test('a miss selects a stream without a full-file downloader', () async {
    var signedRequests = 0;
    final result = await choosePlaybackSource('private-ref',
      lookupCached: (_) async => null,
      resolveRemote: (_) async { signedRequests++; return 'https://media/video.mp4'; },
    );
    expect(result.isLocal, isFalse);
    expect(result.value, 'https://media/video.mp4');
    expect(signedRequests, 1);
  });
  test('authorization failures do not fall back to a public/private raw URL', () {
    expect(choosePlaybackSource('private-ref', lookupCached: (_) async => null,
      resolveRemote: (_) async => throw StateError('forbidden')), throwsStateError);
  });
}
