import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'media_cache_service.dart';

class ChatMediaSaveService {
  static const channel = MethodChannel('zameel/media_export');
  static Future<void> save(
      BuildContext context, String url, String type) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        throw StateError('unsupported');
      }
      messenger.showSnackBar(const SnackBar(content: Text('جارٍ حفظ الملف…')));
      final path = await MediaCacheService.localPathForUrl(url);
      if (path == null) throw StateError('download_failed');
      final saved = await channel
          .invokeMethod<String>('saveOriginal', {'path': path, 'type': type});
      if (saved == null || !saved.startsWith('content://'))
        throw StateError('gallery_save_not_confirmed');
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          content: Text(type == 'audio'
              ? 'تم حفظ الصوت في ملفات الصوت على الهاتف'
              : type == 'video'
                  ? 'تم حفظ الفيديو في الاستديو'
                  : 'تم حفظ الصورة في الاستديو')));
    } catch (_) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'تعذر حفظ الملف على الهاتف. الحفظ متاح حاليًا على أندرويد.')));
    }
  }
}
