import 'package:flutter/material.dart';

class KeepKeyboardSendButton extends StatefulWidget {
  const KeepKeyboardSendButton(
      {super.key, required this.composerFocus, required this.onSend});
  final FocusNode composerFocus;
  final VoidCallback onSend;
  @override
  State<KeepKeyboardSendButton> createState() => _KeepKeyboardSendButtonState();
}

class _KeepKeyboardSendButtonState extends State<KeepKeyboardSendButton> {
  final _buttonFocus = FocusNode(skipTraversal: true, canRequestFocus: false);
  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
      child: IconButton.filled(
          focusNode: _buttonFocus,
          onPressed: () {
            final wasFocused = widget.composerFocus.hasFocus;
            widget.onSend();
            if (wasFocused)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) widget.composerFocus.requestFocus();
              });
          },
          icon: const Icon(Icons.send_rounded)));
}
