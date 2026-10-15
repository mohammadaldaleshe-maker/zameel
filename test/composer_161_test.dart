import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/widgets/mention_field156.dart';
import 'package:zameel/widgets/global_navigation_swipe.dart';

void main() {
  testWidgets(
      'Arabic insertion and composing range survive rebuilds with one input connection',
      (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    final revision = ValueNotifier(0);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ValueListenableBuilder<int>(
      valueListenable: revision,
      builder: (_, value, child) => MentionTextField156(
          controller: controller, focusNode: focus, minLines: 1, maxLines: 5),
    ))));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'مرحبا محمد');
    tester.testTextInput.log.clear();
    const edit = TextEditingValue(
        text: 'مرحبا يا محمد',
        selection: TextSelection.collapsed(offset: 8),
        composing: TextRange(start: 6, end: 8));
    tester.testTextInput.updateEditingValue(edit);
    revision.value++;
    await tester.pump();
    expect(controller.value, edit);
    expect(focus.hasFocus, isTrue);
    expect(
        tester.testTextInput.log.where((call) => [
              'TextInput.hide',
              'TextInput.clearClient',
              'TextInput.setClient'
            ].contains(call.method)),
        isEmpty);
    final before = tester.getSize(find.byType(TextField)).height;
    tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'السطر الأول\nالسطر الثاني\nالسطر الثالث',
        selection: TextSelection.collapsed(offset: 3)));
    await tester.pump();
    expect(tester.getSize(find.byType(TextField)).height, greaterThan(before));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
    revision.dispose();
  });
  testWidgets('edge selection drag in focused editor cannot open navigation',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final owner = Object();
    GlobalNavigationMenu.register(
        owner, (_) => const Drawer(child: Text('NAVIGATION')), () {});
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      builder: (_, child) => GlobalNavigationSwipe(
          navigatorKey: nav, canOpen: () => true, child: child!),
      home: const Scaffold(body: TextField()),
    ));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'نص عربي للتعديل');
    tester.testTextInput.log.clear();
    final gesture = await tester.startGesture(const Offset(790, 25));
    await gesture.moveBy(const Offset(-250, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('NAVIGATION'), findsNothing);
    expect(
        tester.testTextInput.log
            .where((call) => call.method == 'TextInput.clearClient'),
        isEmpty);
    GlobalNavigationMenu.unregister(owner);
    await tester.pumpWidget(const SizedBox());
  });
}
