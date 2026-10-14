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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Map<String, dynamic> row = {};
  late final AnimationController scroll158;
  Timer? tick;
  bool _foreground158 = true;
  int seconds = 0;
  @override
  void initState() {
    super.initState();
    scroll158 =
        AnimationController(vsync: this, duration: const Duration(seconds: 12));
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
    _foreground158 = state == AppLifecycleState.resumed;
    if (_foreground158) {
      _load();
    } else {
      scroll158.stop();
    }
  }

  @override
  void dispose() {
    tick?.cancel();
    scroll158.dispose();
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
    if (!active) {
      scroll158.stop();
      return const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Zameel',
              style: TextStyle(
                  color: Color(0xff3152e8),
                  fontWeight: FontWeight.w900,
                  fontSize: 16)));
    }
    final text = '${row['emoji'] ?? ''}    ${row['label'] ?? ''}    ';
    final style =
        TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.rtl,
          textScaler: MediaQuery.textScalerOf(context))
        ..layout();
      final width = painter.width;
      painter.dispose();
      if (width <= 0) return const SizedBox.shrink();
      // Fixed physical speed, independent of language direction and label length.
      final duration = Duration(
          milliseconds: (width / 28 * 1000).round().clamp(1000, 60000));
      if (scroll158.duration != duration) {
        scroll158.duration = duration;
      }
      if (_foreground158 && !scroll158.isAnimating) scroll158.repeat();
      final copies = (constraints.maxWidth / width).ceil() + 2;
      return SizedBox(
          height: 32,
          child: ClipRect(
              child: AnimatedBuilder(
            animation: scroll158,
            builder: (_, __) => Stack(children: [
              for (var i = 0; i < copies; i++)
                Positioned(
                    left: (i - 1 + scroll158.value) * width,
                    top: 2,
                    width: width,
                    child: Text(text,
                        textDirection: TextDirection.rtl,
                        textScaler: MediaQuery.textScalerOf(context),
                        maxLines: 1,
                        style: style)),
            ]),
          )));
    });
  }
}
