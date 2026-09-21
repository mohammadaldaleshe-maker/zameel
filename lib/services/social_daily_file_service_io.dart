import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class SocialDailyFileService {
  static Future<Uint8List> readPathBytes(String path) => File(path).readAsBytes();

  static Future<String> saveDownload(String filename, Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
