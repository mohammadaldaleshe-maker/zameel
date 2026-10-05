import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zameel/theme/app_theme.dart';
import 'package:zameel/theme/appearance_controller.dart';
import 'package:zameel/widgets/verified_name.dart';
import 'package:zameel/screens/promotions/promotion_locations.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async {
    await AppearanceController.instance.select(AppAppearance.original);
  });

  test(
      'governorate labels preserve city identities and handle existing aliases',
      () {
    expect(promotionGovernorates.toSet().length, 12);
    expect(promotionGovernorateName('مأدبا'), 'مادبا');
    expect(promotionGovernorateName('اربد'), 'إربد');
    final city = {'name': 'السلط', 'governorate': 'البلقاء'};
    expect(promotionCityLabel(city, arabic: true), 'السلط — محافظة البلقاء');
    expect(city['name'], 'السلط');
  });
  testWidgets('long verified names keep badge visible in narrow rows and chips',
      (tester) async {
    final expiry =
        DateTime.now().add(const Duration(days: 1)).toIso8601String();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      SizedBox(
          width: 120,
          child: VerifiedNameLabel(
              expiresAt: expiry,
              child: const Text('اسم مستخدم موثق طويل جدًا',
                  maxLines: 1, overflow: TextOverflow.ellipsis))),
      IntrinsicWidth(
          child:
              VerifiedNameLabel(expiresAt: expiry, child: const Text('اسم'))),
      ActionChip(
          label:
              VerifiedNameLabel(expiresAt: expiry, child: const Text('مستخدم')),
          onPressed: () {}),
    ]))));
    expect(find.byIcon(Icons.verified), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('expired verification keeps name without badge', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: VerifiedNameLabel(
            expiresAt: DateTime.now()
                .subtract(const Duration(seconds: 1))
                .toIso8601String(),
            child: const Text('اسم'))));
    expect(find.byIcon(Icons.verified), findsNothing);
  });

  for (final mode in [
    AppAppearance.original,
    AppAppearance.light,
    AppAppearance.dark
  ]) {
    test(
        '$mode keeps comment, search and chat text readable on neutral surfaces',
        () async {
      await AppearanceController.instance.select(mode);
      for (final surface in [
        AppTheme.adaptiveSurface,
        AppTheme.adaptiveMuted.shade100,
        AppTheme.adaptiveMuted.shade200,
        AppTheme.adaptiveHighlight
      ]) {
        expect(contrast(AppTheme.adaptiveText, surface),
            greaterThanOrEqualTo(4.5));
        expect(contrast(AppTheme.adaptiveSecondary, surface),
            greaterThanOrEqualTo(4.5));
      }
    });
    test('$mode keeps drawer and registration text visible on its page',
        () async {
      await AppearanceController.instance.select(mode);
      for (final background in [AppTheme.pageStart, AppTheme.pageEnd]) {
        expect(contrast(AppTheme.legacyForeground, background),
            greaterThanOrEqualTo(4.5));
        expect(contrast(AppTheme.legacySecondary, background),
            greaterThanOrEqualTo(4.5));
      }
    });
  }
}
