import 'package:zameel/services/mention_display159.dart';

void main() {
  void check(String input, List<String> names, String expected) {
    final actual = mentionBody159(input, names);
    if (actual != expected)
      throw StateError('$input => $actual, expected $expected');
  }

  check('مرحبًا أنا محمد @أسامة عدوي', ['أسامة عدوي'], 'مرحبًا أنا محمد');
  check('@أسامة عدوي', ['أسامة عدوي'], '');
  check('مرحبا @أسامة كيف حالك', ['أسامة'], 'مرحبا كيف حالك');
  check('مرحبا @أسامة، كيف حالك', ['أسامة'], 'مرحبا، كيف حالك');
  check(
      'أهلًا @أسامة عدوي و @أحمد', ['أسامة', 'أسامة عدوي', 'أحمد'], 'أهلًا و');
  check('hello user@example.com', ['example'], 'hello user@example.com');
  check('hello @Unknown', ['أسامة'], 'hello @Unknown');
  check('hello @Johnathan', ['John'], 'hello @Johnathan');
  check('مرحبًا @أسامة2', ['أسامة'], 'مرحبًا @أسامة2');
  check(
      'سطر أول\nمرحبا @أسامة\nسطر ثالث', ['أسامة'], 'سطر أول\nمرحبا\nسطر ثالث');
  check('@الجميع صباح الخير', [], 'صباح الخير');
  check('نص دون إشارة', [], 'نص دون إشارة');
  print(
      'PASS: 12 mention display cases; prose, paragraphs, email addresses, unknown names and name boundaries preserved.');
}
