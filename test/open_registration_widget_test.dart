import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/providers/language_provider.dart';
import 'package:zameel/screens/auth/open_registration_screen.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'local-widget-test',
        debug: false);
  });
  testWidgets('general members skip academic fields; students must select them',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: const MaterialApp(home: OpenRegistrationScreen())));
    expect(find.text('زميل متاح للجميع'), findsOneWidget);
    expect(find.text('الجامعة'), findsNothing);
    expect(find.text('الرقم الجامعي'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('طالب').last);
    await tester.pumpAndSettle();
    expect(find.text('الجامعة'), findsOneWidget);
    expect(find.text('الكلية'), findsOneWidget);
    expect(find.text('التخصص'), findsOneWidget);
    expect(find.text('الدرجة'), findsOneWidget);
    expect(find.text('الرقم الجامعي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
