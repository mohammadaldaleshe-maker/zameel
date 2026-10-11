import 'package:flutter/material.dart';

class TypingMessageBubble extends StatelessWidget {
  const TypingMessageBubble({super.key, required this.arabic});
  final bool arabic;
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.centerLeft,
      child: Container(
          key: const ValueKey('chat-typing-bubble'),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18)),
          child: Semantics(
              liveRegion: true,
              child: Text(arabic ? 'جاري الكتابة…' : 'Typing…',
                  style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant)))));
}
