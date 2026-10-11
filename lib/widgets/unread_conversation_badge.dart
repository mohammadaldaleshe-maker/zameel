import 'package:flutter/material.dart';

class UnreadConversationBadge extends StatelessWidget {
  const UnreadConversationBadge({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => count <= 0
      ? const SizedBox.shrink()
      : Semantics(
          label: '$count رسائل غير مقروءة / unread messages',
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              constraints: const BoxConstraints(minWidth: 24),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16)),
              child: Text(count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold))));
}
