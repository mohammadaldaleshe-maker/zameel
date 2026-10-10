import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/widgets/ai_message_card.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final kind in ['reply', 'user', 'error']) {
      testWidgets('$brightness $kind message and source text stay readable',
          (tester) async {
        final scheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF3152E8), brightness: brightness);
        await tester.pumpWidget(MaterialApp(
            theme: ThemeData(colorScheme: scheme),
            home: Scaffold(
                body: AiMessageCard(
                    text: 'نص المحادثة',
                    isUser: kind == 'user',
                    isError: kind == 'error',
                    verified: true,
                    sourceTitles: const ['دليل زميل']))));
        final card = tester.widget<Container>(find
            .descendant(
                of: find.byType(AiMessageCard),
                matching: find.byType(Container))
            .first);
        final background = (card.decoration! as BoxDecoration).color!;
        final text = tester.widget<SelectableText>(find.byType(SelectableText));
        expect(contrast(text.style!.color!, background),
            greaterThanOrEqualTo(4.5));
        final source = tester.widget<Text>(find.text('المصادر: دليل زميل'));
        expect(contrast(source.style!.color!, background),
            greaterThanOrEqualTo(4.5));
      });
    }
  }
}
