import 'package:flutter/material.dart';

/// The send target shares the editable's tap region and cannot acquire focus.
/// Only open the IME when the composer was not focused before the gesture.
class KeepKeyboardSendButton extends StatelessWidget {
  const KeepKeyboardSendButton(
      {super.key,
      required this.composerFocus,
      required this.onSend,
      this.enabled = true,
      this.busy = false});
  final FocusNode composerFocus;
  final VoidCallback onSend;
  final bool enabled;
  final bool busy;

  void _send() {
    if (!enabled || busy) return;
    if (!composerFocus.hasFocus) composerFocus.requestFocus();
    onSend();
  }

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
      groupId: composerFocus,
      child: ExcludeFocus(
          child: Semantics(
              button: true,
              enabled: enabled && !busy,
              label: 'إرسال / Send',
              onTap: enabled && !busy ? _send : null,
              child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled && !busy ? _send : null,
                  child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle),
                      child: busy
                          ? const Center(
                              child: SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white)))
                          : Icon(Icons.send_rounded,
                              color:
                                  Theme.of(context).colorScheme.onPrimary))))));
}
