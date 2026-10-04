import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'media_cache_service.dart';
import 'video_source_service.dart';

/// One prepared neighbour, never a download of the complete Shorts feed.
class VideoPreloadService {
  static VideoPlayerController? _ready;
  static String? _identity;
  static String? _actor;
  static int _generation = 0;
  static Timer? _expiry;
  static String? get _user => Supabase.instance.client.auth.currentUser?.id;

  static Future<void> clear() async {
    _generation++;
    _expiry?.cancel();
    final old = _ready;
    _ready = null;
    _identity = null;
    _actor = null;
    await old?.dispose();
  }

  static Future<void> warm(String url) async {
    if (url.isEmpty || _user == null) return;
    final identity = MediaCacheService.identity(url);
    if (_identity == identity && _actor == _user) return;
    await clear();
    final generation = _generation;
    final actor = _user;
    VideoPlayerController? controller;
    try {
      _identity = identity;
      _actor = actor;
      controller = await VideoSourceService.controller(url);
      await controller.initialize().timeout(const Duration(seconds: 12));
      await controller.setVolume(0);
      if (generation != _generation || actor != _user) {
        await controller.dispose();
        return;
      }
      _ready = controller;
      _expiry = Timer(const Duration(seconds: 45), () => clear());
    } catch (_) {
      await controller?.dispose();
      if (generation == _generation) {
        _identity = null;
        _actor = null;
      }
    }
  }

  static VideoPlayerController? take(String url) {
    if (_actor != _user || _identity != MediaCacheService.identity(url))
      return null;
    final result = _ready;
    _generation++;
    _expiry?.cancel();
    _ready = null;
    _identity = null;
    _actor = null;
    return result;
  }
}
