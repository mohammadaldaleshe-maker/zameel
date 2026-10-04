import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zameel/theme/appearance_controller.dart';
import 'package:zameel/theme/app_theme.dart';
import 'package:zameel/widgets/compact_post.dart';
import 'package:zameel/widgets/verified_name.dart';

void main() {
  testWidgets(
      'media uses 65 percent screen height while metadata stays full width',
      (tester) async {
    double? height;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 1000)),
            child: Builder(builder: (context) {
              height = postMediaHeight(context);
              return const CompactPost(
                  child: SizedBox(
                      key: ValueKey('metadata'),
                      width: double.infinity,
                      height: 20));
            }))));
    expect(height, 650);
    expect(find.byType(Card), findsNothing);
  });
  testWidgets(
      'appearance changes propagate without disposing page state and save selection',
      (tester) async {
    SharedPreferences.setMockInitialValues({'zameel_appearance': 'light'});
    final controller = AppearanceController.instance;
    await controller.initialize();
    expect(controller.appearance, AppAppearance.light);
    int created = 0;
    await tester.pumpWidget(MaterialApp(
        home:
            AppearanceScope(child: _PaletteProbe(onCreate: () => created++))));
    expect(
        tester.widget<ColoredBox>(find.byKey(const ValueKey('palette'))).color,
        AppTheme.adaptiveBackground);
    await controller.select(AppAppearance.dark);
    await tester.pump();
    expect(
        tester.widget<ColoredBox>(find.byKey(const ValueKey('palette'))).color,
        AppTheme.night);
    expect(created, 1);
    expect(
        (await SharedPreferences.getInstance()).getString('zameel_appearance'),
        'dark');
    await controller.select(AppAppearance.original);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('names without a real account identity never receive a badge',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: VerifiedName(userId: 'demo-user', child: Text('Same name'))));
    expect(find.text('Same name'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

class _PaletteProbe extends StatefulWidget {
  final VoidCallback onCreate;
  const _PaletteProbe({required this.onCreate});
  @override
  State<_PaletteProbe> createState() => _PaletteProbeState();
}

class _PaletteProbeState extends State<_PaletteProbe> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    return ColoredBox(
        key: const ValueKey('palette'), color: AppTheme.adaptiveBackground);
  }
}
