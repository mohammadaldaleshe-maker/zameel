import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zameel/services/sponsored_feed.dart';
import 'package:zameel/services/app_release_gate.dart';
import 'package:zameel/theme/app_theme.dart';
import 'package:zameel/theme/appearance_controller.dart';
import 'package:zameel/widgets/post_media_frame.dart';

Map<String, dynamic> post(String id,
        {String owner = 'other', String audience = 'public'}) =>
    {'id': id, 'user_id': owner, 'audience': audience};

void main() {
  test('owner ads rotate with targeted ads after each five public posts', () {
    final ordinary = [
      post('mine', owner: 'me'),
      for (var i = 1; i <= 10; i++) post('$i')
    ];
    final result = arrangeSponsoredFeed(
        ordinary, [post('mine', owner: 'me'), post('ad1'), post('ad2')], 'me');
    expect(result.map((p) => p['id']),
        ['1', '2', '3', '4', '5', 'mine', '6', '7', '8', '9', '10', 'ad1']);
  });
  test(
      'private rows do not count towards advertising interval; duplicates disappear',
      () {
    final rows = [
      post('p', audience: 'friends'),
      post('p', audience: 'friends'),
      for (var i = 1; i <= 5; i++) post('$i')
    ];
    final result = arrangeSponsoredFeed(rows, [post('ad')], 'me');
    expect(result.map((p) => p['id']), ['p', '1', '2', '3', '4', '5', 'ad']);
    expect(arrangeSponsoredFeed(rows, [], 'me').length, 6);
  });
  test('font grows ten percent without overriding system accessibility scale',
      () {
    expect(const CompactTextScaler(TextScaler.noScaling).scale(20),
        closeTo(18 * 1.1, .00001));
    expect(const CompactTextScaler(TextScaler.linear(1.5)).scale(20),
        closeTo(29.7, .00001));
  });
  test('release gate build agrees with package release', () {
    final source = File('pubspec.yaml').readAsStringSync();
    expect(
        RegExp(
                r'^version:\s*' +
                    RegExp.escape('$zameelVersion+$zameelBuild') +
                    r'\s*$',
                multiLine: true)
            .hasMatch(source),
        isTrue);
  });
  testWidgets('media border follows light and dark appearance', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final appearance = AppearanceController.instance;
    await appearance.initialize();
    for (final mode in [AppAppearance.light, AppAppearance.dark]) {
      await appearance.select(mode);
      await tester.pumpWidget(MaterialApp(
          home: AppearanceScope(
              child:
                  PostMediaFrame(child: SizedBox(width: 100, height: 100)))));
      final decorated = tester.widget<Container>(find
          .descendant(
              of: find.byType(PostMediaFrame), matching: find.byType(Container))
          .first);
      expect((decorated.decoration as BoxDecoration).border,
          Border.all(color: AppTheme.adaptiveGlassBorder, width: 1.5));
      expect(AppTheme.adaptiveText, isNot(AppTheme.adaptiveSurface));
    }
    await appearance.select(AppAppearance.original);
    await tester.pumpWidget(const SizedBox());
  });
}
