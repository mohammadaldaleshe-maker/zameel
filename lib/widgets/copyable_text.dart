import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A local text action surface; ancestor post/message gestures cannot steal
/// the long press. The dialog has its own selection area and copy fallback.
class CopyableText extends StatelessWidget {
  const CopyableText(this.data,
      {super.key,
      this.style,
      this.onTap,
      this.maxLines,
      this.overflow,
      this.textAlign});
  final String? data;
  final TextStyle? style;
  final VoidCallback? onTap;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  Future<void> _select(BuildContext context) async {
    final text = data ?? '';
    if (text.isEmpty) return;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(ar ? 'تحديد النص' : 'Select text'),
              content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                      child: SelectableText(text,
                          enableInteractiveSelection: true))),
              actions: [
                TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (c.mounted) Navigator.pop(c);
                    },
                    child: Text(ar ? 'نسخ الكل' : 'Copy all')),
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: Text(ar ? 'إغلاق' : 'Close')),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: data,
      onLongPress: () => _select(context),
      child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: () => _select(context),
          child: Text(data ?? '',
              style: style,
              maxLines: maxLines,
              overflow: overflow,
              textAlign: textAlign)));
}
