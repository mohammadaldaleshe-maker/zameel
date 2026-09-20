import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/config.dart';

void main() {
  test('Zameel production configuration has required defaults', () {
    expect(ZameelConfig.supabaseUrl, startsWith('https://'));
    expect(ZameelConfig.supabasePublishableKey, isNotEmpty);
    expect(ZameelConfig.appName, 'Zameel');
  });
}
