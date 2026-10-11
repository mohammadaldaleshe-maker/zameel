import 'package:zameel/services/story_seen_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zameel/widgets/keep_keyboard_send_button.dart';
import 'package:zameel/widgets/global_navigation_swipe.dart';
import 'package:zameel/widgets/typing_message_bubble.dart';
import 'package:zameel/widgets/unread_conversation_badge.dart';
import 'package:zameel/widgets/copyable_text.dart';
import 'package:zameel/services/story_order_service.dart';

void main() {
  testWidgets(
      'send retains the same text input connection without hide/clearClient',
      (tester) async {
    final focus = FocusNode();
    final composer = TextEditingController();
    var sends = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SelectionArea(
                child: Row(children: [
      Expanded(
          child: TextField(
              groupId: focus,
              focusNode: focus,
              controller: composer,
              textInputAction: TextInputAction.send,
              onEditingComplete: () {})),
      KeepKeyboardSendButton(
          composerFocus: focus,
          onSend: () {
            sends++;
            composer.clear();
          }),
    ])))));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'message one');
    tester.testTextInput.log.clear();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(focus.hasFocus, true);
    expect(tester.testTextInput.hasAnyClients, true);
    expect(sends, 1);
    expect(
        tester.testTextInput.log.where((c) => [
              'TextInput.hide',
              'TextInput.clearClient',
              'TextInput.setClient'
            ].contains(c.method)),
        isEmpty);
    await tester.enterText(find.byType(TextField), 'message two');
    tester.testTextInput.log.clear();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(sends, 2);
    expect(
        tester.testTextInput.log.where((c) => [
              'TextInput.hide',
              'TextInput.clearClient',
              'TextInput.setClient'
            ].contains(c.method)),
        isEmpty);
    await tester.pumpWidget(const SizedBox());
    composer.dispose();
    focus.dispose();
  });
  testWidgets(
      'message options remain in the selection dialog without permanent dots',
      (tester) async {
    var options = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CopyableText('Message', onOptions: () => options++))));
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    await tester.longPress(find.text('Message'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.text('Message options'));
    await tester.pumpAndSettle();
    expect(options, 1);
  });
  testWidgets(
      'typing is a peer-side timeline bubble and unread counts are bounded visually',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Column(children: [
      TypingMessageBubble(arabic: true),
      UnreadConversationBadge(count: 3),
      UnreadConversationBadge(count: 150),
      UnreadConversationBadge(count: 0)
    ]))));
    expect(find.text('جاري الكتابة…'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('chat-typing-bubble'))).dx,
        0);
  });
  testWidgets(
      'drawer follows partial drag, cancels, commits, and closes by reverse drag',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final owner = Object();
    GlobalNavigationMenu.register(
        owner,
        (_) =>
            const Drawer(key: ValueKey('finger-drawer'), child: Text('Menu')),
        () {});
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [GlobalNavigationMenu.observer],
        builder: (_, child) => GlobalNavigationSwipe(
            navigatorKey: nav, canOpen: () => true, child: child!),
        home: const Scaffold(body: Text('Home'))));
    var hand = await tester.startGesture(const Offset(795, 200));
    await hand.moveBy(const Offset(-140, 0));
    await tester.pump();
    final partial =
        tester.getTopLeft(find.byKey(const ValueKey('finger-drawer'))).dx;
    expect(partial, greaterThan(496));
    expect(partial, lessThan(800));
    await hand.moveBy(const Offset(135, 0));
    await tester.pump();
    await hand.up();
    await tester.pumpAndSettle();
    expect(find.text('Menu'), findsNothing);
    hand = await tester.startGesture(const Offset(795, 200));
    await hand.moveBy(const Offset(-200, 0));
    await tester.pump();
    await hand.up();
    await tester.pumpAndSettle();
    expect(find.text('Menu'), findsOneWidget);
    hand = await tester.startGesture(const Offset(600, 200));
    await hand.moveBy(const Offset(180, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey('finger-drawer'))).dx,
        greaterThan(496));
    await hand.up();
    await tester.pumpAndSettle();
    expect(find.text('Menu'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    GlobalNavigationMenu.unregister(owner);
  });
  testWidgets(
      'profile follows the finger, cancelled swipe stays home and full swipe retains profile',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final owner = Object();
    GlobalNavigationMenu.register(owner, (_) => const Drawer(), () {},
        profilePageBuilder: () async => const Scaffold(
            key: ValueKey('finger-profile'), body: Text('Profile')));
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [GlobalNavigationMenu.observer],
        builder: (_, child) => GlobalNavigationSwipe(
            navigatorKey: nav, canOpen: () => true, child: child!),
        home: const Scaffold(body: Text('Home'))));
    var hand = await tester.startGesture(const Offset(5, 200));
    await hand.moveBy(const Offset(160, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey('finger-profile'))).dx,
        lessThan(0));
    await hand.moveBy(const Offset(-155, 0));
    await tester.pump();
    await hand.up();
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsNothing);
    hand = await tester.startGesture(const Offset(5, 200));
    await hand.moveBy(const Offset(350, 0));
    await tester.pump();
    await hand.up();
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    GlobalNavigationMenu.unregister(owner);
  });
  test(
      'unwatched groups first, newest first, watched last and own tray remains pinned',
      () {
    Map<String, dynamic> story(String id, String owner, String time, bool seen,
            {bool mine = false}) =>
        {
          'id': id,
          'user_id': owner,
          'created_at': time,
          'viewed': seen,
          'isMine': mine
        };
    final rows = [
      story('1', 'seen', '2026-10-11T12:00:00Z', true),
      story('2', 'older', '2026-10-10T10:00:00Z', false),
      story('3', 'new', '2026-10-11T11:00:00Z', false),
      story('4', 'own', '2026-10-10T09:00:00Z', true, mine: true)
    ];
    final groups = orderedStoryGroups(rows);
    expect(
        groups.map((g) => g.first['user_id']), ['own', 'new', 'older', 'seen']);
    rows[2]['viewed'] = true;
    expect(orderedStoryGroups(rows).map((g) => g.first['user_id']),
        ['own', 'older', 'seen', 'new']);
    expect(rows.map((r) => r['id']),
        ['1', '2', '3', '4']); // Viewer snapshot is never mutated by sorting.
  });
  test('viewed IDs survive refresh and are isolated per account', () async {
    SharedPreferences.setMockInitialValues({});
    await StorySeenStore.save('account-a', {'story-1', 'story-2'});
    expect(await StorySeenStore.load('account-a'), {'story-1', 'story-2'});
    expect(await StorySeenStore.load('account-b'), isEmpty);
  });
}
