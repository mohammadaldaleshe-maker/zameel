import 'dart:io';
import 'package:path_provider/path_provider.dart';

class VoiceRecordingFile {
  static Future<String> createPath() async =>
      '${(await getTemporaryDirectory()).path}/zameel_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
  static Future<void> remove(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
