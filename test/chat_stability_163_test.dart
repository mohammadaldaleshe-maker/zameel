import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/providers/language_provider.dart';
import 'package:zameel/screens/chat/chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.test',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            detectSessionInUri: false, autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final rpc = request.url.path.split('/').last;
          dynamic value;
          if (rpc == 'zameel_chat_messages') {
            value = List.generate(
                35,
                (i) => {
                      'id': 'message-$i',
                      'sender_id': 'partner',
                      'content': 'رسالة عربية للتجربة رقم $i',
                      'created_at':
                          DateTime.utc(2026, 10, 15, 10, i).toIso8601String()
                    });
          } else if (rpc == 'zameel_chat_presence') {
            value = {'is_online': false};
          } else if (rpc == 'zameel_chat_typing_get') {
            value = false;
          } else {
            value = [];
          }
          return http.Response(jsonEncode(value), 200,
              headers: {'content-type': 'application/json'}, request: request);
        }));
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets(
      'unchanged sync preserves reading offset and Arabic editor connection',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: const MaterialApp(
            home: ChatDetailScreen(
                conversationId: 'conversation',
                partnerId: 'partner',
                partnerName: 'زميل اختبار',
                allowCalls: false))));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final list = tester.widget<ListView>(find.byType(ListView).first);
    final scroll = list.controller!;
    expect(scroll.position.maxScrollExtent, greaterThan(100));
    scroll.jumpTo(80);
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(scroll.offset, closeTo(80, .01));
    final editor = find.byKey(const ValueKey('direct-chat-composer'));
    await tester.tap(editor);
    await tester.enterText(editor, 'مرحبا محمد');
    tester.testTextInput.log.clear();
    const edit = TextEditingValue(
        text: 'مرحبا يا محمد',
        selection: TextSelection.collapsed(offset: 8),
        composing: TextRange(start: 6, end: 8));
    tester.testTextInput.updateEditingValue(edit);
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    final field = tester.widget<TextField>(editor);
    expect(field.controller!.value, edit);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(
        tester.testTextInput.log.where((call) => [
              'TextInput.hide',
              'TextInput.clearClient',
              'TextInput.setClient'
            ].contains(call.method)),
        isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    await tester.runAsync(() => Supabase.instance.client.realtime.disconnect());
  });
}
