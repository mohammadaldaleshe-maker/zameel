import 'visibility_pulse163.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Counts an exposure only after at least half the card is visible for a second.
/// Each return to the card is a new exposure; retries retain one event identity.
class SponsoredExposure extends StatefulWidget {
  final String postId;
  final Widget child;
  final bool partner;
  final DateTime Function()? now;
  const SponsoredExposure({
    super.key,
    required this.postId,
    required this.child,
    this.partner = false,
    this.now,
  });
  @override
  State<SponsoredExposure> createState() => _SponsoredExposureState();
}

class _SponsoredExposureState extends State<SponsoredExposure> {
  DateTime? _visibleSince;
  bool _busy = false, _recorded = false, _denied = false, _clicked = false;
  Offset? _pointerStart;
  DateTime? _pointerTime;
  late final String _actor;
  late String _event;
  @override
  void initState() {
    super.initState();
    _actor = Supabase.instance.client.auth.currentUser?.id ?? '';
    _event = _newEvent();
    VisibilityPulse163.add(_check);
  }

  String _newEvent() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _endVisit() {
    _visibleSince = null;
    if (!_busy && (_recorded || _denied)) {
      _recorded = false;
      _denied = false;
      _clicked = false;
      _event = _newEvent();
    }
  }

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  void _check() {
    if (!mounted) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true ||
        Supabase.instance.client.auth.currentUser?.id != _actor) {
      _endVisit();
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
      _endVisit();
      return;
    }
    if (_denied || _recorded || _busy) return;
    _visibleSince ??= _now();
    if (_now().difference(_visibleSince!) >= const Duration(seconds: 1)) {
      unawaited(_record());
    }
  }

  Future<void> _record() async {
    _busy = true;
    try {
      final accepted = await Supabase.instance.client.rpc(
        widget.partner
            ? 'zameel_record_advertisement162'
            : 'zameel_record_promotion',
        params: {
          if (widget.partner)
            'p_ad': widget.postId
          else
            'p_post': widget.postId,
          'p_event': _event,
          if (!widget.partner) 'p_click': false,
        },
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      _recorded = accepted == true;
      _denied = !_recorded;
    } catch (_) {
      // Retry the same event identity; failed requests never inflate counters.
      _visibleSince = null;
    } finally {
      _busy = false;
    }
  }

  Future<void> _click() async {
    if (widget.partner ||
        !_recorded ||
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
    VisibilityPulse163.remove(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
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
