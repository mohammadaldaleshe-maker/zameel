import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Central screen-awake policy for Zameel.
///
/// Normal app usage keeps the screen awake for two minutes after the most
/// recent interaction. Long-running experiences such as calls, meetings and
/// maps can hold a persistent lease while they are visible.
class ScreenAwakeService {
  ScreenAwakeService._();

  static const Duration normalAwakeWindow = Duration(minutes: 2);
  static Timer? _idleTimer;
  static int _persistentLeases = 0;
  static bool _awake = false;

  static Future<void> initialize() async {
    await registerActivity();
  }

  static Future<void> registerActivity() async {
    if (_persistentLeases > 0) return;
    _idleTimer?.cancel();
    await _setAwake(true);
    _idleTimer = Timer(normalAwakeWindow, () {
      if (_persistentLeases == 0) {
        _setAwake(false);
      }
    });
  }

  static Future<void> enterPersistent() async {
    _persistentLeases += 1;
    _idleTimer?.cancel();
    await _setAwake(true);
  }

  static Future<void> exitPersistent() async {
    if (_persistentLeases > 0) _persistentLeases -= 1;
    if (_persistentLeases == 0) {
      await registerActivity();
    }
  }

  static Future<void> _setAwake(bool value) async {
    if (_awake == value) return;
    try {
      if (value) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
      _awake = value;
    } catch (error) {
      // Screen-awake behavior must never prevent Zameel from starting or
      // leaving a call on a platform where wakelock is temporarily unavailable.
      debugPrint('Screen awake update failed: $error');
    }
  }
}

/// Wrap a screen that must remain awake for its whole lifetime.
class ScreenAwakeScope extends StatefulWidget {
  final Widget child;

  const ScreenAwakeScope({super.key, required this.child});

  @override
  State<ScreenAwakeScope> createState() => _ScreenAwakeScopeState();
}

class _ScreenAwakeScopeState extends State<ScreenAwakeScope> {
  @override
  void initState() {
    super.initState();
    ScreenAwakeService.enterPersistent();
  }

  @override
  void dispose() {
    ScreenAwakeService.exitPersistent();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
