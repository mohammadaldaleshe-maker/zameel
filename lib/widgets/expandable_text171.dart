import 'package:flutter/material.dart';

/// Shows [builder] limited to [collapsedLines] lines. When the text is longer
/// than that, a "عرض المزيد" / "عرض أقل" button appears under it.
///
/// [builder] receives the line limit to apply (null while expanded) and the
/// matching overflow, so any existing text widget can be reused unchanged.
/// Short texts are shown exactly as before, with no button.
class ExpandableText171 extends StatefulWidget {
  const ExpandableText171({
    super.key,
    required this.text,
    required this.builder,
    this.style,
    this.collapsedLines = 3,
    this.expandedMaxHeight,
    this.buttonColor,
  });

  final String text;
  final TextStyle? style;
  final int collapsedLines;

  /// When set, the expanded text scrolls inside this height instead of
  /// growing the surrounding layout (used inside fixed-height panels).
  final double? expandedMaxHeight;
  final Color? buttonColor;
  final Widget Function(BuildContext context, int? maxLines,
      TextOverflow? overflow) builder;

  @override
  State<ExpandableText171> createState() => _ExpandableText171State();
}

class _ExpandableText171State extends State<ExpandableText171> {
  bool _expanded = false;

  // Remembers the answer per text and width, so scrolling a long feed never
  // lays the same text out again.
  static final Map<String, bool> _measured = <String, bool>{};

  bool _overflows(BuildContext context, double maxWidth) {
    if (widget.text.trim().isEmpty || !maxWidth.isFinite || maxWidth <= 0) {
      return false;
    }
    // A short single-paragraph text cannot reach the line limit: skip measuring.
    if (widget.text.length <= widget.collapsedLines * 12 &&
        !widget.text.contains('\n')) {
      return false;
    }
    final fontSize = (widget.style ?? DefaultTextStyle.of(context).style)
            .fontSize ??
        14;
    final cacheKey =
        '${widget.collapsedLines}|${maxWidth.round()}|$fontSize|${widget.text.hashCode}|${widget.text.length}';
    final known = _measured[cacheKey];
    if (known != null) return known;
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: widget.collapsedLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    if (_measured.length > 400) _measured.clear();
    _measured[cacheKey] = exceeded;
    return exceeded;
  }

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return LayoutBuilder(builder: (context, constraints) {
      final long = _overflows(context, constraints.maxWidth);
      if (!long) return widget.builder(context, null, null);
      Widget body = widget.builder(
        context,
        _expanded ? null : widget.collapsedLines,
        _expanded ? null : TextOverflow.ellipsis,
      );
      final cap = widget.expandedMaxHeight;
      if (_expanded && cap != null) {
        body = ConstrainedBox(
          constraints: BoxConstraints(maxHeight: cap),
          child: SingleChildScrollView(child: body),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
          InkWell(
            key: const ValueKey('expandableTextToggle171'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _expanded
                    ? (arabic ? 'عرض أقل' : 'Show less')
                    : (arabic ? 'عرض المزيد' : 'Show more'),
                style: TextStyle(
                  color: widget.buttonColor ??
                      Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
