import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/providers/language_provider.dart';
import 'package:zameel/screens/auth/open_registration_screen.dart';
import 'package:zameel/main.dart' show refreshAcademicCatalog156;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        authOptions:
            const FlutterAuthClientOptions(detectSessionInUri: false),
        url: 'http://localhost:54321',
        anonKey: 'local-widget-test',
        debug: false,
        httpClient: MockClient((request) async => http.Response(
            jsonEncode([
              {
                'name': 'جامعة مضافة من الإدارة',
                'type': 'حكومية',
                'city': 'عمّان',
                'colleges': [
                  {
                    'name': 'كلية مضافة',
                    'departments': ['تخصص مضاف'],
                    'programDegrees': {
                      'تخصص مضاف': ['bachelor']
                    }
                  }
                ]
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request)));
  });
  testWidgets('general members skip academic fields; students must select them',
      (tester) async {
    await tester.runAsync(() => refreshAcademicCatalog156());
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: const MaterialApp(home: OpenRegistrationScreen())));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
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
