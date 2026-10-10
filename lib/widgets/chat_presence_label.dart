import 'package:flutter/material.dart';

class ChatPresenceLabel extends StatelessWidget {
  const ChatPresenceLabel(
      {super.key,
      required this.typing,
      required this.online,
      required this.arabic});
  final bool typing, online, arabic;
  @override
  Widget build(BuildContext context) {
    if (!typing && !online) return const SizedBox.shrink();
    return Text(
        typing
            ? (arabic ? 'جارٍ الكتابة…' : 'Typing…')
            : (arabic ? 'متصل الآن' : 'Online'),
        style: const TextStyle(fontSize: 12, color: Colors.green));
  }
}
