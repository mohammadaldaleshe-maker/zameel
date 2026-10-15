import 'dart:io';
import 'package:flutter/services.dart';

import 'package:path_provider/path_provider.dart';

class SocialDailyFileService {
  static Future<Uint8List> readPathBytes(String path) =>
      File(path).readAsBytes();

  static Future<String> saveDownload(String filename, Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    try {
      final uri = await const MethodChannel('zameel/media_export')
          .invokeMethod<String>(
              'saveOriginal', {'path': file.path, 'type': 'image'});
      if (uri == null || !uri.startsWith('content://'))
        throw StateError('gallery_save_not_confirmed');
      return uri;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}
