import 'dart:typed_data';

class SocialDailyFileService {
  static Future<Uint8List> readPathBytes(String path) {
    throw UnsupportedError('Local recording files are unavailable on this platform.');
  }

  static Future<String> saveDownload(String filename, Uint8List bytes) {
    throw UnsupportedError('Direct downloads are unavailable on this platform.');
  }
}
