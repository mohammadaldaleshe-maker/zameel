import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

/// Copy/selection behavior is retained; only explicit HTTP(S) links open externally.
class CopyableText extends StatefulWidget {
  const CopyableText(this.data,
      {super.key,
      this.style,
      this.onTap,
      this.onOptions,
      this.maxLines,
      this.overflow,
      this.textAlign});
  final String? data;
  final TextStyle? style;
  final VoidCallback? onTap, onOptions;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  @override
  State<CopyableText> createState() => _CopyableTextState();
}

class _CopyableTextState extends State<CopyableText> {
  final _recognizers = <TapGestureRecognizer>[];
  void _clear() {
    for (final r in _recognizers) r.dispose();
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  Future<void> _select() async {
    final text = widget.data ?? '';
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
                  if (widget.onOptions != null)
                    TextButton(
                        onPressed: () {
                          Navigator.pop(c);
                          widget.onOptions!();
                        },
                        child: Text(ar ? 'خيارات الرسالة' : 'Message options')),
                  TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (c.mounted) Navigator.pop(c);
                      },
                      child: Text(ar ? 'نسخ الكل' : 'Copy all')),
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(ar ? 'إغلاق' : 'Close'))
                ]));
  }

  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final text = widget.data ?? '', spans = <InlineSpan>[];
    int cursor = 0;
    for (final match in RegExp(r'https?://[^\s<>]+', caseSensitive: false)
        .allMatches(text)) {
      var link = match.group(0)!.replaceFirst(RegExp(r'[.,،؛!?]+$'), '');
      for (final pair in ['()', '[]']) {
        while (link.endsWith(pair[1]) &&
            pair[1].allMatches(link).length > pair[0].allMatches(link).length) {
          link = link.substring(0, link.length - 1);
        }
      }
      if (link.isEmpty) continue;
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
      final r = TapGestureRecognizer()..onTap = () => _open(link);
      _recognizers.add(r);
      spans.add(TextSpan(
          text: link,
          style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xff93c5fd)
                  : const Color(0xff1747bd),
              decoration: TextDecoration.underline),
          recognizer: r));
      cursor = match.start + link.length;
    }
    spans.add(TextSpan(text: text.substring(cursor)));
    final child = _recognizers.isEmpty
        ? Text(text,
            style: widget.style,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
            textAlign: widget.textAlign)
        : Text.rich(TextSpan(children: spans),
            style: widget.style,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
            textAlign: widget.textAlign);
    return Semantics(
        label: widget.data,
        onLongPress: _select,
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onLongPress: _select,
            child: child));
  }
}
