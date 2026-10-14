import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/services/header_occasion_156.dart';
import 'package:zameel/widgets/copyable_text.dart';

void main() {
  final start = DateTime.utc(2026, 10, 12);
  var now = start;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.test',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
        httpClient: MockClient((r) async => http.Response(
            jsonEncode({
              'enabled': true,
              'emoji': '🇯🇴',
              'label': 'عيد الاستقلال',
              'color': '#ffffff',
              'starts_at':
                  start.subtract(const Duration(days: 1)).toIso8601String(),
              'ends_at': start.add(const Duration(days: 1)).toIso8601String()
            }),
            200,
            request: r,
            headers: {'content-type': 'application/json'})));
  });
  tearDownAll(() async => Supabase.instance.dispose());
  test('requested text always has readable contrast on all three backgrounds',
      () {
    for (final bg in [
      Colors.white,
      const Color(0xff171928),
      const Color(0xff3152e8)
    ]) {
      final fg = occasionTextColor156(const Color(0xff3152e8), bg),
          a = fg.computeLuminance(),
          b = bg.computeLuminance();
      expect(((a > b ? a : b) + .05) / ((a > b ? b : a) + .05),
          greaterThanOrEqualTo(4.5));
    }
  });
  testWidgets('continuous rightward ticker and expiry restores Zameel',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            appBar: AppBar(title: HeaderOccasion156(now: () => now)))));
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('🇯🇴    عيد الاستقلال'), findsWidgets);
    final positions = find.byWidgetPredicate((w) =>
        w is Positioned &&
        w.width != null &&
        w.child is Text &&
        ((w.child as Text).data ?? '').contains('عيد الاستقلال'));
    final before = tester.widget<Positioned>(positions.first).left!;
    await tester.pump(const Duration(milliseconds: 300));
    final after = tester.widget<Positioned>(positions.first).left!;
    expect(after, greaterThan(before));
    expect(tester.takeException(), isNull);
    now = start.add(const Duration(days: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Zameel'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('links preserve text and copy selection surface', (tester) async {
    const text = 'رابط https://example.invalid/path ثم نص';
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CopyableText(text))));
    expect(find.text(text, findRichText: true), findsWidgets);
    expect(find.byType(RichText), findsWidgets);
    await tester.longPress(find.byType(CopyableText));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('نسخ الكل'), findsNothing);
    expect(find.text('Copy all'), findsOneWidget);
  });
}
