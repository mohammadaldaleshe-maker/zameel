import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/providers/language_provider.dart';
import 'package:zameel/screens/comments/comments_screen.dart';
import 'package:zameel/widgets/keep_keyboard_send_button.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'http://localhost:54321', anonKey: 'local-test', debug: false);
  });
  testWidgets('busy send and repeated rebuilds retain the IME client',
      (tester) async {
    final focus = FocusNode();
    final controller = TextEditingController();
    bool busy = false;
    int sends = 0;
    late StateSetter redraw;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
      redraw = setState;
      return Row(children: [
        Expanded(
            child: TextField(
                controller: controller,
                focusNode: focus,
                groupId: focus,
                onEditingComplete: () {})),
        KeepKeyboardSendButton(
            composerFocus: focus,
            busy: busy,
            onSend: () {
              sends++;
              controller.clear();
              redraw(() => busy = true);
            })
      ]);
    }))));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'first');
    tester.testTextInput.log.clear();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.tap(find.byType(KeepKeyboardSendButton));
    await tester.pump();
    expect(sends, 1);
    redraw(() => busy = false);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(
        tester.testTextInput.log.where((call) => [
              'TextInput.hide',
              'TextInput.clearClient',
              'TextInput.setClient'
            ].contains(call.method)),
        isEmpty);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(430, 932),
    const Size(640, 360)
  ]) {
    testWidgets(
        'composer stays visible on $size and restores preview after keyboard closes',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
          child: MaterialApp(
              home: CommentsScreen(
                  post: {'text': List.filled(100, 'وصف طويل').join(' ')}))));
      await tester.pump();
      final composer = find.byKey(const ValueKey('comment-composer'));
      final preview = find.byKey(const ValueKey('comment-post-preview'));
      expect(preview, findsOneWidget);
      expect(
          tester.getBottomRight(composer).dy, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
      await tester.tap(composer);
      await tester.pump();
      // Focus hides the preview even before an IME reports its insets.
      expect(preview, findsNothing);
      for (final keyboardHeight
          in size.height < 400 ? [120.0, 170.0] : [200.0, 320.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        await tester.pump();
        expect(preview, findsNothing);
        expect(tester.getBottomRight(composer).dy,
            lessThanOrEqualTo(size.height - keyboardHeight));
        expect(find.byIcon(Icons.send_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      expect(preview, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
