import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../platform/video_controller_factory.dart';
import 'media_cache_service.dart';
import 'secure_media_service.dart';
import 'playback_source.dart';

/// Use an existing local file or stream on demand. Never wait for an entire
/// video to download and never start a second download beside the player.
class VideoSourceService {
  VideoSourceService._();
  static Future<VideoPlayerController> controller(String value) async {
    final localUri = Uri.tryParse(value);
    if (!kIsWeb &&
        (localUri?.scheme == 'file' ||
            value.startsWith('/') ||
            RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value))) {
      return videoControllerFromLocalPath(
          localUri?.scheme == 'file' ? localUri!.toFilePath() : value);
    }
    final source = await choosePlaybackSource(
      value,
      lookupCached: (url) => kIsWeb
          ? Future<String?>.value(null)
          : MediaCacheService.localPathForUrl(url, downloadIfMissing: false),
      resolveRemote: SecureMediaService.resolve,
    );
    if (source.isLocal) return videoControllerFromLocalPath(source.value);
    return VideoPlayerController.networkUrl(Uri.parse(source.value));
  }
}
