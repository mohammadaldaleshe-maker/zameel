import '../services/mention_display159.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'copyable_text.dart';
import '../screens/profile/profile_screen.dart';

class MentionContent158 extends StatefulWidget {
  const MentionContent158(this.text,
      {super.key,
      required this.kind,
      required this.id,
      this.style,
      this.header = false,
      this.onTap,
      this.maxLines,
      this.overflow});
  final String? text;
  final String kind, id;
  final TextStyle? style;
  final bool header;
  final VoidCallback? onTap;
  final int? maxLines;
  final TextOverflow? overflow;
  @override
  State<MentionContent158> createState() => _MentionContent158State();
}

class _MentionContent158State extends State<MentionContent158> {
  Map<String, String> names = {};
  int generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MentionContent158 old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id ||
        old.kind != widget.kind ||
        old.text != widget.text) _load();
  }

  Future<void> _load() async {
    final request = ++generation;
    if (widget.id.isEmpty || !(widget.text ?? '').contains('@')) {
      if (mounted && names.isNotEmpty) setState(() => names = {});
      return;
    }
    try {
      final rows = await Supabase.instance.client.rpc('zameel_mentions_read158',
          params: {'p_kind': widget.kind, 'p_id': widget.id});
      if (mounted && request == generation)
        setState(() => names = {
              for (final row in rows as List) '${row['name']}': '${row['id']}'
            });
    } catch (_) {
      if (mounted && request == generation) setState(() => names = {});
    }
  }

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.header &&
                names.isNotEmpty &&
                !(widget.text ?? '').contains('@الجميع'))
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                const Text('مع '),
                for (final entry in names.entries)
                  TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ProfileScreen(userId: entry.value))),
                      child: Text(entry.key)),
              ]),
            if (widget.header && (widget.text ?? '').contains('@الجميع'))
              const Text('مع الأصدقاء والمتابعين'),
            if (!widget.header ||
                mentionBody159(widget.text ?? '', names.keys).isNotEmpty)
              CopyableText(
                  widget.header
                      ? mentionBody159(widget.text ?? '', names.keys)
                      : widget.text,
                  mentions: {
                    ...names,
                    if ((widget.text ?? '').contains('@الجميع')) 'الجميع': '*'
                  },
                  style: widget.style,
                  onTap: widget.onTap,
                  maxLines: widget.maxLines,
                  overflow: widget.overflow),
          ]);
}
