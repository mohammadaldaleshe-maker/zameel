import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'media_cache_service.dart';

class WatermarkedDownloadService {
  static const _channel = MethodChannel('zameel/media_export');
  static bool _busy = false;
  static Future<void> download(
    BuildContext context, {
    required String type,
    required String id,
    int index = 0,
  }) async {
    if (_busy) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تنزيل الوسائط متاح حاليًا على Android')));
      return;
    }
    _busy = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        duration: Duration(seconds: 3),
        content: Text('جارٍ تنزيل الوسائط وإضافة اسم صاحبها وشعار زميل…')));
    final navigator = Navigator.of(context, rootNavigator: true);
    final progress = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
            content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('جارٍ حفظ الوسائط بعلامة زميل…')),
        ])),
      ),
    );
    navigator.push(progress);
    final db = Supabase.instance.client;
    final actor = db.auth.currentUser?.id;
    try {
      final raw = await db.rpc('zameel_download_media', params: {
        'p_type': type,
        'p_id': id,
        'p_index': index
      }).timeout(const Duration(seconds: 10));
      final media = Map<String, dynamic>.from(raw as Map);
      final path = await MediaCacheService.localPathForUrl('${media['url']}');
      if (path == null)
        throw StateError('تعذر تنزيل الملف؛ تحقق من اتصال الإنترنت');
      if (actor == null || actor != db.auth.currentUser?.id) return;
      await _channel.invokeMethod<String>('export', {
        'path': path,
        'video': media['type'] == 'video',
        'owner': media['owner'],
      });
      if (context.mounted)
        messenger.showSnackBar(const SnackBar(
            content: Text('تم حفظ الملف بعلامة زميل واسم صاحب المحتوى')));
    } catch (e) {
      if (context.mounted)
        messenger.showSnackBar(SnackBar(
            content: Text(e is PlatformException
                ? (e.message ?? 'تعذر حفظ الملف')
                : 'تعذر تنزيل المحتوى أو لا تسمح خصوصيته بالتنزيل')));
    } finally {
      if (progress.isActive) navigator.removeRoute(progress);
      _busy = false;
    }
  }
}
