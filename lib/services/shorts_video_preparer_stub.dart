import 'package:image_picker/image_picker.dart';
import 'shorts_video_result.dart';
Future<PreparedShort> prepareShortVideo(XFile source, {XFile? cover}) async {
  if (cover == null) throw StateError('short_cover_required_on_web');
  return PreparedShort(source, cover, () async {});
}
