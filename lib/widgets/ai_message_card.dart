import 'package:flutter/material.dart';

/// Paired foreground/background colors follow the active Material theme.
class AiMessageCard extends StatelessWidget {
  const AiMessageCard(
      {super.key,
      required this.text,
      this.isUser = false,
      this.isError = false,
      this.verified = false,
      this.sourceTitles = const []});
  final String text;
  final bool isUser, isError, verified;
  final List<String> sourceTitles;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = isUser
        ? colors.primaryContainer
        : isError
            ? colors.errorContainer
            : colors.surfaceContainerHighest;
    final foreground = isUser
        ? colors.onPrimaryContainer
        : isError
            ? colors.onErrorContainer
            : colors.onSurface;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (verified)
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_rounded, size: 17, color: foreground),
                  const SizedBox(width: 4),
                  Text('إجابة معتمدة من زميل',
                      style: TextStyle(
                          color: foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ])),
          SelectableText(text,
              style: TextStyle(color: foreground, height: 1.5)),
          if (sourceTitles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('المصادر: ${sourceTitles.join('، ')}',
                style: TextStyle(fontSize: 11, color: foreground)),
          ],
        ]),
      ),
    );
  }
}
