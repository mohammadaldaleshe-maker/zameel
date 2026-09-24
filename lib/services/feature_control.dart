import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global switches from the admin console. Unknown switches stay available so
/// an older database does not silently remove existing app functionality.
class FeatureControl {
  FeatureControl._();
  static final instance = FeatureControl._();
  final changes = ValueNotifier<int>(0);
  Map<String, String> _modes = {};
  DateTime? _lastRefresh;
  Future<void>? _pending;

  String mode(String key) => _modes[key] ?? 'enabled';
  bool visible(String key) => mode(key) != 'hidden';
  bool enabled(String key) => mode(key) == 'enabled';

  static const suspendedMessage = 'هذه الميزة معلقة حالياً';

  static bool isSuspendedError(Object error) {
    final message = error is PostgrestException ? error.message : error.toString();
    return RegExp(r'\b[a-z_]+_temporarily_unavailable\b').hasMatch(message);
  }

  /// Converts backend feature guards to one safe, consistent UI message.
  /// Other errors retain the caller's existing explanation.
  static String errorMessage(Object error, String fallback) {
    if (isSuspendedError(error)) {
      return suspendedMessage;
    }
    return '$fallback: $error';
  }

  Future<bool> check(BuildContext context, String key) async {
    await refresh(force: true);
    if (!context.mounted) return false;
    if (enabled(key)) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(suspendedMessage)),
    );
    return false;
  }

  /// Also covers a screen reached through an old link or while its switch changes.
  Widget page(String key, Widget child, {bool embedded = false}) =>
      _FeaturePage(featureKey: key, embedded: embedded, child: child);

  Future<void> refresh({bool force = false}) {
    if (_pending != null) return _pending!;
    if (!force && _lastRefresh != null &&
        DateTime.now().difference(_lastRefresh!) < const Duration(seconds: 30)) {
      return Future<void>.value();
    }
    final completer = Completer<void>();
    _pending = completer.future;
    () async {
      try {
        final rows = await Supabase.instance.client.rpc('get_client_feature_flags');
        final next = <String, String>{};
        for (final row in (rows as List)) {
          final data = Map<String, dynamic>.from(row as Map);
          if (data['scope_type'] != 'global' || data['scope_value'] != '*') continue;
          final key = data['feature_key']?.toString();
          if (key == null) continue;
          final mode = data['display_mode']?.toString();
          next[key] = mode == 'hidden' || mode == 'suspended'
              ? mode!
              : data['is_enabled'] == false ? 'suspended' : 'enabled';
        }
        _modes = next;
        _lastRefresh = DateTime.now();
        changes.value++;
      } catch (_) {
        // Preserve the last verified state during short network outages.
      } finally {
        _pending = null;
        completer.complete();
      }
    }();
    return completer.future;
  }

  Future<void> open(BuildContext context, String key, Widget Function() page) async {
    if (!await check(context, key) || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => this.page(key, page())));
  }
}

class _FeaturePage extends StatefulWidget {
  const _FeaturePage({required this.featureKey, required this.child,
      required this.embedded});
  final String featureKey;
  final Widget child;
  final bool embedded;

  @override
  State<_FeaturePage> createState() => _FeaturePageState();
}

class _FeaturePageState extends State<_FeaturePage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    FeatureControl.instance.refresh(force: true);
    _timer = Timer.periodic(const Duration(seconds: 45),
        (_) => FeatureControl.instance.refresh(force: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: FeatureControl.instance.changes,
    builder: (context, _, __) => FeatureControl.instance.enabled(widget.featureKey)
        ? widget.child
        : widget.embedded
            ? const Padding(padding: EdgeInsets.all(16),
                child: Text(FeatureControl.suspendedMessage))
            : const Scaffold(body: Center(child: Text(FeatureControl.suspendedMessage))),
  );
}
