import 'package:zameel/theme/app_theme.dart';
import 'dart:async';
import '../../services/home_snapshot_service.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../../services/feature_control.dart';
import '../../widgets/cached_media_image.dart';
import 'public_clips_strip.dart';

class ShortsGateway extends StatelessWidget {
  const ShortsGateway({super.key});
  @override
  Widget build(BuildContext context) {
    final ar = context.watch<LanguageProvider>().isArabic;
    void open() =>
        FeatureControl.instance.check(context, 'clips').then((allowed) {
          if (allowed && context.mounted)
            showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(36))),
                builder: (_) => _ShortsFan(ar: ar));
        });
    return SafeArea(
        top: false,
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -100) open();
          },
          onTap: open,
          child: Container(
              height: 48,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 5),
                    Text(ar ? 'اسحب و افتح عالمك' : 'Swipe and open your world',
                        style: const TextStyle(
                            color: Colors.teal, fontWeight: FontWeight.bold)),
                  ])),
        ));
  }
}

class _ShortsFan extends StatefulWidget {
  const _ShortsFan({required this.ar});
  final bool ar;
  @override
  State<_ShortsFan> createState() => _ShortsFanState();
}

class _ShortsFanState extends State<_ShortsFan> {
  List<Map<String, dynamic>> _clips = [];
  int _center = 0;
  String? _error;
  bool _loading = true;
  bool _remoteShown = false;
  @override
  void initState() {
    super.initState();
    _restore();
    _load();
  }

  Future<void> _restore() async {
    final actor = Supabase.instance.client.auth.currentUser?.id;
    if (actor == null) return;
    final rows = await HomeSnapshotService.read(actor, 'clips');
    if (mounted &&
        !_remoteShown &&
        actor == Supabase.instance.client.auth.currentUser?.id &&
        rows.isNotEmpty) {
      setState(() {
        _clips = rows;
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    final actor = Supabase.instance.client.auth.currentUser?.id;
    try {
      final raw = await Supabase.instance.client.rpc('zameel_shorts_feed');
      final rows = (raw as List)
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      if (mounted && actor == Supabase.instance.client.auth.currentUser?.id) {
        _remoteShown = true;
        setState(() {
          _clips = rows;
          _center = 0;
          _loading = false;
          _error = null;
        });
        if (actor != null)
          unawaited(HomeSnapshotService.save(actor, 'clips', rows));
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = _clips.isEmpty
              ? (widget.ar ? 'تعذر تحميل الشورتس' : 'Could not load Shorts')
              : null;
        });
    }
  }

  Future<void> _open(int index) async {
    await openShortsViewer(context, _clips, index);
    final actor = Supabase.instance.client.auth.currentUser?.id;
    final cached = actor == null
        ? <Map<String, dynamic>>[]
        : await HomeSnapshotService.read(actor, 'clips');
    if (mounted) {
      if (cached.isEmpty)
        setState(() {
          _clips = [];
          _loading = true;
        });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: SizedBox(
          height: 390,
          child: Column(children: [
            Text(widget.ar ? 'زميل شورتس' : 'Zameel Shorts',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: TextButton(
                                onPressed: _load, child: Text(_error!)))
                        : _clips.isEmpty
                            ? Center(
                                child: Text(widget.ar
                                    ? 'لا توجد مقاطع متاحة'
                                    : 'No Shorts available'))
                            : LayoutBuilder(builder: (context, size) {
                                final width =
                                    math.min(140.0, size.maxWidth * .32);
                                return GestureDetector(
                                    onHorizontalDragEnd: (d) {
                                      final step =
                                          (d.primaryVelocity ?? 0) < 0 ? 1 : -1;
                                      setState(() => _center = (_center + step)
                                          .clamp(0, _clips.length - 1)
                                          .toInt());
                                    },
                                    child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          for (final offset in [
                                            -2,
                                            2,
                                            -1,
                                            1,
                                            0
                                          ])
                                            if (_center + offset >= 0 &&
                                                _center + offset <
                                                    _clips.length)
                                              Positioned(
                                                  left:
                                                      (size.maxWidth - width) /
                                                              2 +
                                                          offset *
                                                              size.maxWidth *
                                                              .13,
                                                  top: 20.0 +
                                                      offset.abs() * 23.0,
                                                  child: Transform.rotate(
                                                      angle: offset * .14,
                                                      child: GestureDetector(
                                                          onTap: () => _open(
                                                              _center + offset),
                                                          child: Container(
                                                            width: width,
                                                            height: 210,
                                                            clipBehavior:
                                                                Clip.antiAlias,
                                                            decoration: BoxDecoration(
                                                                color: Colors
                                                                    .teal
                                                                    .shade900,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            22),
                                                                border: Border.all(color: Colors.white, width: 3),
                                                                boxShadow: const [
                                                                  BoxShadow(
                                                                      color: Colors
                                                                          .black26,
                                                                      blurRadius:
                                                                          12)
                                                                ]),
                                                            child: (_clips[_center + offset]['cover_url']
                                                                            ?.toString() ??
                                                                        '')
                                                                    .isEmpty
                                                                ? const SizedBox
                                                                    .expand()
                                                                : CachedMediaImage(
                                                                    url: _clips[_center +
                                                                                offset]
                                                                            [
                                                                            'cover_url']
                                                                        .toString(),
                                                                    fit: BoxFit
                                                                        .cover,
                                                                    cacheWidth:
                                                                        320,
                                                                    fallback:
                                                                        const SizedBox
                                                                            .expand()),
                                                          )))),
                                        ]));
                              })),
            FilledButton(
                onPressed: _clips.isEmpty
                    ? null
                    : () => _open(math.Random().nextInt(_clips.length)),
                child: Text(widget.ar ? 'فاجئني' : 'Surprise me')),
            const SizedBox(height: 16),
            Text(widget.ar ? 'اسحب و افتح عالمك' : 'Swipe and open your world'),
            const SizedBox(height: 12),
          ])));
}
