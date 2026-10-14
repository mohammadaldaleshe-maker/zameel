/// Hide only verified mention tokens in post/short bodies. Stored text and
/// notification identities remain unchanged; comments keep their inline links.
String mentionBody159(String text, Iterable<String> names) {
  final labels = {...names, 'الجميع'}.where((name) => name.isNotEmpty).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (labels.isEmpty) return text;
  final pattern = RegExp(
      r'(^|\s)@(?:' +
          labels.map(RegExp.escape).join('|') +
          r')(?![\p{L}\p{N}_])',
      unicode: true);
  if (!pattern.hasMatch(text)) return text;
  return text
      .replaceAllMapped(pattern, (m) => m.group(1) ?? '')
      .replaceAllMapped(RegExp(r'[ \t]+([،,؛;.!؟?])'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .trim();
}
