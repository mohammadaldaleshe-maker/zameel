import 'dart:async';
import 'package:flutter/foundation.dart';

/// One clock for mounted media and campaign cards. No widget owns a poller.
class VisibilityPulse163 {
  static final Set<VoidCallback> _listeners = {};
  static Timer? _timer;

  static void add(VoidCallback listener) {
    _listeners.add(listener);
    _timer ??= Timer.periodic(const Duration(milliseconds: 300), (_) {
      for (final callback in List<VoidCallback>.of(_listeners)) {
        if (_listeners.contains(callback)) callback();
      }
    });
  }

  static void remove(VoidCallback listener) {
    _listeners.remove(listener);
    if (_listeners.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }
}
