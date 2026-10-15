import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:zameel/services/social_daily_file_service_io.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  var success = true;
  final seen = <int>[];
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('gallery161');
    PathProviderPlatform.instance = _Paths(root.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zameel/media_export'),
            (call) async {
      expect(call.method, 'saveOriginal');
      expect((call.arguments as Map)['type'], 'image');
      seen.addAll(
          await File((call.arguments as Map)['path'] as String).readAsBytes());
      return success ? 'content://media/external/images/media/161' : null;
    });
  });
  tearDownAll(() async {
    await root.delete(recursive: true);
  });
  test(
      'college download waits for native gallery confirmation and removes staging file',
      () async {
    success = true;
    expect(
        await SocialDailyFileService.saveDownload(
            'photo161.jpg', Uint8List.fromList([1, 2, 3])),
        'content://media/external/images/media/161');
    expect(seen, [1, 2, 3]);
    expect(await File('${root.path}/photo161.jpg').exists(), false);
  });
  test('missing gallery receipt is failure and cannot be reported as saved',
      () async {
    success = false;
    await expectLater(
        SocialDailyFileService.saveDownload(
            'failed161.jpg', Uint8List.fromList([4, 5])),
        throwsStateError);
    expect(await File('${root.path}/failed161.jpg').exists(), false);
  });
}
