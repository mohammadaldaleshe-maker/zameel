import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/profile/profile_screen.dart';

class MentionController156 extends TextEditingController {
  final Map<String, String> selected = {};
  List<String> get mentionIds => selected.entries
      .where((e) => text.contains('@${e.value}'))
      .map((e) => e.key)
      .toList();
}

class MentionTextField156 extends StatefulWidget {
  const MentionTextField156(
      {super.key,
      required this.controller,
      this.minLines,
      this.maxLines = 5,
      this.maxLength,
      this.autofocus = false,
      this.style,
      this.cursorColor,
      this.decoration = const InputDecoration()});
  final TextEditingController controller;
  final int? minLines, maxLines, maxLength;
  final bool autofocus;
  final TextStyle? style;
  final Color? cursorColor;
  final InputDecoration decoration;
  @override
  State<MentionTextField156> createState() => _MentionTextField156State();
}

class _MentionTextField156State extends State<MentionTextField156> {
  Timer? debounce;
  List<Map<String, dynamic>> rows = [];
  String? query;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    generation++;
    debounce?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  RegExpMatch? _match() {
    final pos = widget.controller.selection.baseOffset;
    if (pos < 0) return null;
    return RegExp(r'(^|\s)@([^\s@]*)$')
        .firstMatch(widget.controller.text.substring(0, pos));
  }

  void _changed() {
    final match = _match(), next = match?.group(2);
    if (next == query) return;
    query = next;
    final request = ++generation;
    debounce?.cancel();
    if (next == null) {
      if (mounted) setState(() => rows = []);
      return;
    }
    debounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final data = await Supabase.instance.client
            .rpc('zameel_mention_candidates_156', params: {'p_query': next});
        if (mounted && request == generation)
          setState(() => rows = List<Map<String, dynamic>>.from(data as List));
      } catch (_) {
        if (mounted && request == generation) setState(() => rows = []);
      }
    });
  }

  void _select(Map<String, dynamic> row) {
    final match = _match();
    if (match == null) return;
    final text = widget.controller.text,
        position = widget.controller.selection.baseOffset,
        start = match.start + (match.group(1)?.length ?? 0),
        label = '@${row['name']} ';
    if (widget.controller is MentionController156)
      (widget.controller as MentionController156).selected['${row['id']}'] =
          '${row['name']}';
    widget.controller.value = TextEditingValue(
        text: text.replaceRange(start, position, label),
        selection: TextSelection.collapsed(offset: start + label.length));
    setState(() => rows = []);
  }

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            controller: widget.controller,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            autofocus: widget.autofocus,
            style: widget.style,
            cursorColor: widget.cursorColor,
            decoration: widget.decoration),
        if (rows.isNotEmpty)
          SizedBox(
              height: 150,
              child: ListView(
                  shrinkWrap: true,
                  children: rows
                      .map((r) => ListTile(
                          dense: true,
                          title: Text('${r['name']}'),
                          leading: const Icon(Icons.alternate_email),
                          onTap: () => _select(r)))
                      .toList()))
      ]);
}

class MentionLinks156 extends StatefulWidget {
  const MentionLinks156({super.key, required this.postId});
  final String postId;
  @override
  State<MentionLinks156> createState() => _MentionLinks156State();
}

class _MentionLinks156State extends State<MentionLinks156> {
  List<Map<String, dynamic>> rows = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Supabase.instance.client.rpc(
          'zameel_post_mentions_read156',
          params: {'p_post': widget.postId});
      if (mounted)
        setState(() => rows = List<Map<String, dynamic>>.from(r as List));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Wrap(
      children: rows
          .map((r) => TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: '${r['id']}'))),
              child: Text('@${r['name']}')))
          .toList());
}
