import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// One piece of a message: plain text, or a link that can be tapped.
class LinkPart165 {
  const LinkPart165(this.text, this.url);
  final String text;
  final String? url;
}

/// Splits [text] into plain parts and http/https/www links.
/// Trailing punctuation (for example a full stop after a link) is not part of
/// the link.
List<LinkPart165> splitLinks165(String text) {
  final parts = <LinkPart165>[];
  final pattern = RegExp(r'(https?://[^\s]+|www\.[^\s]+)', caseSensitive: false);
  var cursor = 0;
  for (final match in pattern.allMatches(text)) {
    var raw = match.group(0) ?? '';
    var end = match.end;
    while (raw.isNotEmpty && '.,;:!?)]}،؛؟"\''.contains(raw[raw.length - 1])) {
      raw = raw.substring(0, raw.length - 1);
      end--;
    }
    if (raw.isEmpty) continue;
    if (match.start > cursor) {
      parts.add(LinkPart165(text.substring(cursor, match.start), null));
    }
    final url = raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw;
    parts.add(LinkPart165(raw, url));
    cursor = end;
  }
  if (cursor < text.length) {
    parts.add(LinkPart165(text.substring(cursor), null));
  }
  return parts;
}

/// Text whose links open in the browser. Safe in chat bubbles on any colour:
/// pass the bubble's [style] and, optionally, a [linkColor].
class LinkifiedText165 extends StatefulWidget {
  const LinkifiedText165(this.text, {super.key, this.style, this.linkColor});
  final String text;
  final TextStyle? style;
  final Color? linkColor;

  @override
  State<LinkifiedText165> createState() => _LinkifiedText165State();
}

class _LinkifiedText165State extends State<LinkifiedText165> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  List<LinkPart165> _parts = const <LinkPart165>[];
  final List<TapGestureRecognizer?> _partRecognizers =
      <TapGestureRecognizer?>[];

  @override
  void initState() {
    super.initState();
    _rebuildParts();
  }

  @override
  void didUpdateWidget(covariant LinkifiedText165 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _rebuildParts();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    _partRecognizers.clear();
  }

  void _rebuildParts() {
    _disposeRecognizers();
    _parts = splitLinks165(widget.text);
    for (final part in _parts) {
      final url = part.url;
      if (url == null) {
        _partRecognizers.add(null);
      } else {
        final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
        _recognizers.add(recognizer);
        _partRecognizers.add(recognizer);
      }
    }
  }

  Future<void> _open(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final linkStyle = base.copyWith(
      color: widget.linkColor ?? base.color,
      decoration: TextDecoration.underline,
      decorationColor: widget.linkColor ?? base.color,
    );
    final spans = <InlineSpan>[];
    for (var i = 0; i < _parts.length; i++) {
      final part = _parts[i];
      spans.add(TextSpan(
        text: part.text,
        style: part.url == null ? null : linkStyle,
        recognizer: _partRecognizers[i],
      ));
    }
    return Text.rich(TextSpan(children: spans), style: widget.style);
  }
}
