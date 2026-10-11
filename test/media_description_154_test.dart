import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/widgets/media_description_dialog.dart';
import 'package:zameel/widgets/chat_timestamp.dart';
import 'package:zameel/widgets/keep_keyboard_send_button.dart';

void main() {
  testWidgets('caption is returned trimmed; empty caption still publishes',
      (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showDialog<String>(
                          context: context,
                          builder: (_) =>
                              const MediaDescriptionDialog(mediaCount: 3));
                    },
                    child: const Text('فتح'))))));
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('home_media_description')),
        '  وصف الوسائط  ');
    await tester.tap(find.text('نشر'));
    await tester.pumpAndSettle();
    expect(result, 'وصف الوسائط');
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نشر'));
    await tester.pumpAndSettle();
    expect(result, '');
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
  test('chat dates handle month/year boundaries and preserve message rows', () {
    expect(
        chatDay(DateTime(2025, 12, 31, 10).toIso8601String(),
            now: DateTime(2026, 1, 1)),
        'أمس');
    expect(
        chatDay(DateTime(2026, 1, 1, 10).toIso8601String(),
            now: DateTime(2026, 1, 1)),
        'اليوم');
    expect(chatTime(DateTime(2026, 1, 1, 9, 7).toIso8601String()), '09:07');
    final rows = [
      {'id': 'one', 'created_at': DateTime(2026, 1, 1, 10).toIso8601String()},
      {'id': 'two', 'created_at': DateTime(2026, 1, 2, 10).toIso8601String()},
    ];
    final dated = chatDatedRows(rows);
    expect(dated.where((row) => row['date_separator'] == true).length, 2);
    expect(dated.where((row) => row['date_separator'] != true).toList(), rows);
    expect(rows.length, 2);
  });
  testWidgets('send keeps composer focused without a focus-loss frame',
      (tester) async {
    final focus = FocusNode();
    var sent = 0;
    final states = <bool>[];
    focus.addListener(() => states.add(focus.hasFocus));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      TextField(focusNode: focus, groupId: focus),
      KeepKeyboardSendButton(
          composerFocus: focus,
          onSend: () {
            sent++;
          }),
    ]))));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    states.clear();
    await tester.tap(find.byType(KeepKeyboardSendButton));
    await tester.pump();
    expect(sent, 1);
    expect(focus.hasFocus, isTrue);
    expect(states, isNot(contains(false)));
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
  });
}
