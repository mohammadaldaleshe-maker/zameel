import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'share_cover157_stub.dart' if (dart.library.io) 'share_cover157_io.dart'
    as platform;

Future<XFile?> videoShareCover157(String path) async {
  try {
    final result = await const MethodChannel('zameel/share_preview157')
        .invokeMethod<String>('videoCover', {'path': path});
    return result == null || result.isEmpty ? null : XFile(result);
  } catch (_) {
    return null;
  }
}

Future<void> removeShareCover157(XFile file) =>
    platform.removeCover157(file.path);
