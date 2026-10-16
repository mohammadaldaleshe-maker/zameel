import 'dart:io';
import 'dart:ui' as ui;
import 'media_cache_service.dart';

/// Read encoded dimensions without decoding a full-resolution image into RAM.
Future<double?> mediaAspectRatio163(String url) async {
  final path = await MediaCacheService.localPathForUrl(url);
  if (path == null) return null;
  final buffer = Platform.isWindows
      ? await ui.ImmutableBuffer.fromUint8List(await File(path).readAsBytes())
      : await ui.ImmutableBuffer.fromFilePath(path);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return descriptor.width > 0 && descriptor.height > 0
          ? descriptor.width / descriptor.height
          : null;
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
