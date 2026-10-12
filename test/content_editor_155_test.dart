import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/widgets/content_editor155.dart';

void main() {
  testWidgets(
      'post editor retains multiple media until explicitly removed and can cancel',
      (tester) async {
    final row = {
      'id': 'post',
      'text_ar': 'نص المنشور',
      'text_en': 'caption',
      'image_url': null,
      'video_url': null,
      'media_items': [
        {'type': 'image', 'url': 'old-image'},
        {'type': 'video', 'url': 'old-video'}
      ]
    };
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog(
                        context: context,
                        builder: (_) =>
                            ContentEditor155(table: 'posts', row: row)),
                    child: const Text('فتح'))))));
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    expect(find.text('صورة 1'), findsOneWidget);
    expect(find.text('فيديو 2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    expect(find.text('فيديو 1'), findsOneWidget);
    expect((row['media_items'] as List).length, 2);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.byType(ContentEditor155), findsNothing);
  });
  testWidgets('radio anonymity is editable without exposing storage paths',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: ContentEditor155(table: 'zameel_radio_posts', row: {
      'id': 'radio',
      'is_anonymous': false,
      'storage_path': 'private-recording'
    }))));
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.text('private-recording'), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, true);
  });
}
