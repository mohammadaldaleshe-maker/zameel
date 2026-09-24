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
    await refresh(force: true);
    if (!context.mounted) return;
    if (!enabled(key)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        mode(key) == 'hidden' ? 'هذه الميزة غير متاحة حاليًا' : 'هذه الميزة معلّقة مؤقتًا',
      )));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page()));
  }
}
