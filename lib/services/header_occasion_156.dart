import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Color occasionTextColor156(Color requested, Color background) {
  double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
  }

  if (contrast(requested, background) >= 4.5) return requested;
  return contrast(Colors.white, background) > contrast(Colors.black, background)
      ? Colors.white
      : Colors.black;
}

class HeaderOccasion156 extends StatefulWidget {
  const HeaderOccasion156({super.key, this.now});
  final DateTime Function()? now;
  @override
  State<HeaderOccasion156> createState() => _HeaderOccasion156State();
}

class _HeaderOccasion156State extends State<HeaderOccasion156>
    with WidgetsBindingObserver {
  Map<String, dynamic> row = {};
  Timer? tick;
  int seconds = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
      if (seconds % 60 == 0) _load();
    });
  }

  Future<void> _load() async {
    try {
      final data =
          await Supabase.instance.client.rpc('zameel_header_current_156');
      if (mounted) setState(() => row = Map<String, dynamic>.from(data as Map));
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final end = DateTime.tryParse('${row['ends_at']}');
    final start = DateTime.tryParse('${row['starts_at']}');
    final now = widget.now?.call() ?? DateTime.now();
    final active = row['enabled'] == true &&
        start != null &&
        end != null &&
        !now.isBefore(start) &&
        now.isBefore(end);
    final requested = Color(int.tryParse(
            'FF${('${row['color']}').replaceFirst('#', '')}',
            radix: 16) ??
        0xff3152e8);
    final theme = Theme.of(context);
    final color = occasionTextColor156(requested,
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor);
    final label = active
        ? (seconds % 10 < 5 ? '${row['emoji']}' : '${row['label']}')
        : 'Zameel';
    return SizedBox(
        width: 150,
        child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(label,
                key: ValueKey(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: active ? color : const Color(0xff3152e8),
                    fontWeight: FontWeight.w900,
                    fontSize: active && seconds % 10 < 5 ? 26 : 16))));
  }
}
