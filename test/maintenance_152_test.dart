import 'package:zameel/widgets/chat_presence_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/widgets/copyable_text.dart';
import 'package:zameel/widgets/keep_keyboard_send_button.dart';
import 'package:zameel/widgets/global_navigation_swipe.dart';

void main() {
  testWidgets('typing remains visible even when online heartbeat is false',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body:
                ChatPresenceLabel(typing: true, online: false, arabic: true))));
    expect(find.text('جارٍ الكتابة…'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: ChatPresenceLabel(
                typing: false, online: false, arabic: true))));
    expect(find.text('جارٍ الكتابة…'), findsNothing);
  });

  testWidgets(
      'single tap invokes reaction; long press selects and copies actual message text',
      (tester) async {
    var reactions = 0;
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData')
        copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CopyableText('Test message', onTap: () => reactions++))));
    await tester.tap(find.text('Test message'));
    await tester.pump();
    expect(reactions, 1);
    await tester.longPress(find.text('Test message'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(reactions, 1);
    await tester.tap(find.text('Copy all'));
    await tester.pumpAndSettle();
    expect(copied, 'Test message');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
      'repeated send taps preserve composer focus and text input connection',
      (tester) async {
    final focus = FocusNode();
    final controller = TextEditingController();
    var sent = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Row(children: [
      Expanded(child: TextField(focusNode: focus, controller: controller)),
      KeepKeyboardSendButton(
          composerFocus: focus,
          onSend: () {
            sent++;
            controller.clear();
          }),
    ]))));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'one');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    await tester.enterText(find.byType(TextField), 'two');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(sent, 2);
    expect(focus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
    controller.dispose();
  });

  testWidgets(
      'right edge opens real menu on pushed route; center swipe leaves it closed; left edge opens profile only at root',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final owner = Object();
    var profiles = 0;
    GlobalNavigationMenu.register(owner,
        (c) => const Drawer(child: Text('Menu content')), () => profiles++);
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [GlobalNavigationMenu.observer],
        builder: (c, child) => GlobalNavigationSwipe(
            navigatorKey: nav, canOpen: () => true, child: child!),
        home: const Scaffold(body: Text('Home'))));
    await tester.dragFrom(const Offset(10, 250), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(profiles, 1);
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other screen'))));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(10, 250), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(profiles, 1);
    await tester.dragFrom(const Offset(400, 250), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Menu content'), findsNothing);
    await tester.dragFrom(const Offset(795, 250), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Menu content'), findsOneWidget);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Other screen'), findsOneWidget);
    GlobalNavigationMenu.unregister(owner);
  });
}
