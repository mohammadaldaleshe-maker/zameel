import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Counts an exposure only after at least half the card is visible for a second.
/// The server binds the actor, enforces the daily cap and deduplicates retries.
class SponsoredExposure extends StatefulWidget {
  final String postId;
  final Widget child;
  const SponsoredExposure({
    super.key,
    required this.postId,
    required this.child,
  });
  @override
  State<SponsoredExposure> createState() => _SponsoredExposureState();
}

class _SponsoredExposureState extends State<SponsoredExposure> {
  Timer? _timer;
  DateTime? _visibleSince;
  bool _busy = false, _recorded = false, _denied = false, _clicked = false;
  Offset? _pointerStart;
  DateTime? _pointerTime;
  late final String _actor;
  late final String _event;
  @override
  void initState() {
    super.initState();
    _actor = Supabase.instance.client.auth.currentUser?.id ?? '';
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _event =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _check());
  }

  void _check() {
    if (!mounted || _denied || _recorded || _busy) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true ||
        Supabase.instance.client.auth.currentUser?.id != _actor) {
      _visibleSince = null;
      return;
    }
    final object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) return;
    final origin = object.localToGlobal(Offset.zero);
    final rect = origin & object.size;
    var visible = rect.intersect(Offset.zero & MediaQuery.sizeOf(context));
    final scroll = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (scroll is RenderBox && scroll.hasSize) {
      visible = visible.intersect(
        scroll.localToGlobal(Offset.zero) & scroll.size,
      );
    }
    if (rect.height <= 0 ||
        visible.height <= 0 ||
        visible.width <= 0 ||
        visible.width * visible.height < rect.width * rect.height * .5) {
      _visibleSince = null;
      return;
    }
    _visibleSince ??= DateTime.now();
    if (DateTime.now().difference(_visibleSince!) >=
        const Duration(seconds: 1)) {
      unawaited(_record());
    }
  }

  Future<void> _record() async {
    _busy = true;
    try {
      final accepted = await Supabase.instance.client.rpc(
        'zameel_record_promotion',
        params: {
          'p_post': widget.postId,
          'p_event': _event,
          'p_click': false,
        },
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _recorded = accepted == true;
        _denied = !_recorded;
      });
      _timer?.cancel();
    } catch (_) {
      // Retry the same event identity; failed requests never inflate counters.
      _visibleSince = null;
    } finally {
      _busy = false;
    }
  }

  Future<void> _click() async {
    if (!_recorded ||
        _clicked ||
        Supabase.instance.client.auth.currentUser?.id != _actor) return;
    _clicked = true;
    try {
      await Supabase.instance.client.rpc(
        'zameel_record_promotion',
        params: {
          'p_post': widget.postId,
          'p_event': _event,
          'p_click': true,
        },
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      _clicked = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _denied
      ? const SizedBox.shrink()
      : Listener(
          onPointerDown: (event) {
            _pointerStart = event.position;
            _pointerTime = DateTime.now();
          },
          onPointerCancel: (_) {
            _pointerStart = null;
          },
          onPointerUp: (event) {
            final start = _pointerStart;
            final time = _pointerTime;
            _pointerStart = null;
            if (start != null &&
                time != null &&
                (event.position - start).distance < 8 &&
                DateTime.now().difference(time) <
                    const Duration(milliseconds: 500)) {
              unawaited(_click());
            }
          },
          child: widget.child,
        );
}
