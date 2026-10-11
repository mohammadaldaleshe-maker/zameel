import 'package:flutter/material.dart';

/// A send target that never joins a FocusScope or changes the input connection.
class KeepKeyboardSendButton extends StatelessWidget {
  const KeepKeyboardSendButton(
      {super.key, required this.composerFocus, required this.onSend});
  final FocusNode composerFocus;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => SelectionContainer.disabled(
      child: TextFieldTapRegion(
          groupId: composerFocus,
          child: Semantics(
              button: true,
              label: 'إرسال / Send',
              onTap: onSend,
              child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSend,
                  child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle),
                      child: Icon(Icons.send_rounded,
                          color: Theme.of(context).colorScheme.onPrimary))))));
}
