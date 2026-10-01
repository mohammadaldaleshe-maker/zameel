import 'package:image_picker/image_picker.dart';
class PreparedShort {
  const PreparedShort(this.video, this.cover, this.cleanup);
  final XFile video;
  final XFile? cover;
  final Future<void> Function() cleanup;
}
