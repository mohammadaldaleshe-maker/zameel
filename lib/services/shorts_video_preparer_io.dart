import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'shorts_video_result.dart';
Future<PreparedShort> prepareShortVideo(XFile source, {XFile? cover}) async {
  if (!Platform.isAndroid && !Platform.isIOS) return PreparedShort(source, cover, () async {});
  final temporary = <File>[];
  var video = source;
  try {
    final result = await VideoCompress.compressVideo(source.path,
      quality: VideoQuality.HighestQuality, deleteOrigin: false, includeAudio: true);
    final compressedPath = result?.path;
    if (compressedPath != null && compressedPath != source.path) {
      final candidate = File(compressedPath);
      temporary.add(candidate);
      if (await candidate.length() < await source.length()) video = XFile(candidate.path);
    }
    if (cover == null) {
      final thumbnail = await VideoCompress.getFileThumbnail(video.path, quality: 70, position: 1000);
      temporary.add(thumbnail);
      cover = XFile(thumbnail.path);
    }
    return PreparedShort(video, cover, () async {
      for (final file in temporary) { try { if (await file.exists()) await file.delete(); } catch (_) {} }
    });
  } catch (_) {
    for (final file in temporary) { try { if (await file.exists()) await file.delete(); } catch (_) {} }
    rethrow;
  }
}
