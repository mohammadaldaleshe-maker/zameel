import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'verified_badge.dart';

/// Batch only the identities already displayed; never infer verification by name.
class VerificationDirectory extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = VerificationDirectory._();
  VerificationDirectory._();
  final Map<String, int> _watched = {};
  final Map<String, String?> _expiry = {};
  final Set<String> _pending = {};
  Timer? _batch, _refresh;
  StreamSubscription<AuthState>? _auth;
  bool _initialized = false, _paused = false;
  int _generation = 0;
  String? expiry(String id) => _expiry[id];
  void clear() {
    _generation++;
    _expiry.clear();
    _pending.clear();
    notifyListeners();
  }

  void updateOwn(String id, String? expiresAt) {
    if (Supabase.instance.client.auth.currentUser?.id != id) return;
    _expiry[id] = expiresAt;
    notifyListeners();
  }

  void watch(String id) {
    if (id.isEmpty) return;
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
      _auth = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedOut ||
            state.event == AuthChangeEvent.signedIn) {
          _generation++;
          _expiry.clear();
          _pending.clear();
          notifyListeners();
          _reload();
        }
      });
    }
    _watched[id] = (_watched[id] ?? 0) + 1;
    if (!_expiry.containsKey(id)) _queue(id);
    _refresh ??= Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_paused) _reload();
    });
  }

  void unwatch(String id) {
    final count = (_watched[id] ?? 0) - 1;
    if (count <= 0) {
      _watched.remove(id);
      _expiry.remove(id);
      _pending.remove(id);
    } else {
      _watched[id] = count;
    }
    if (_watched.isEmpty) {
      _refresh?.cancel();
      _refresh = null;
    }
  }

  void _reload() {
    for (final id in _watched.keys) {
      _pending.add(id);
    }
    _schedule();
  }

  void _queue(String id) {
    _pending.add(id);
    _schedule();
  }

  void _schedule() {
    if (_paused || _pending.isEmpty) return;
    _batch ??= Timer(const Duration(milliseconds: 40), _fetch);
  }

  Future<void> _fetch() async {
    _batch = null;
    final ids = _pending.take(100).toList();
    _pending.removeAll(ids);
    final generation = _generation;
    try {
      if (Supabase.instance.client.auth.currentUser == null) return;
      final rows = await Supabase.instance.client.rpc(
          'zameel_verification_badges',
          params: {'p_users': ids}).timeout(const Duration(seconds: 8));
      if (generation != _generation) return;
      for (final id in ids) {
        if (_watched.containsKey(id)) _expiry[id] = null;
      }
      if (rows is List) {
        for (final row in rows) {
          final id = row['user_id']?.toString();
          if (id != null && _watched.containsKey(id))
            _expiry[id] = row['expires_at']?.toString();
        }
      }
      notifyListeners();
    } catch (_) {
      /* Existing expiry still expires locally; retry next refresh. */
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (_paused) {
      _batch?.cancel();
      _batch = null;
    } else {
      _reload();
    }
  }

  @override
  void dispose() {
    _batch?.cancel();
    _refresh?.cancel();
    _auth?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class VerifiedName extends StatefulWidget {
  final String? userId;
  final Text child;
  const VerifiedName({super.key, required this.userId, required this.child});
  @override
  State<VerifiedName> createState() => _VerifiedNameState();
}

class _VerifiedNameState extends State<VerifiedName> {
  final directory = VerificationDirectory.instance;
  String get id {
    final value = widget.userId ?? '';
    return RegExp(
                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(value)
        ? value
        : '';
  }

  @override
  void initState() {
    super.initState();
    directory.watch(id);
  }

  @override
  void didUpdateWidget(covariant VerifiedName old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      directory.unwatch(old.userId ?? '');
      directory.watch(id);
    }
  }

  @override
  void dispose() {
    directory.unwatch(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: directory,
      builder: (context, child) {
        final child = widget.child;
        final expiry = directory.expiry(id);
        final end = DateTime.tryParse(expiry ?? '');
        if (id.isEmpty || end == null || !end.isAfter(DateTime.now()))
          return child;
        return VerifiedNameLabel(expiresAt: expiry, child: child);
      });
}

/// Reserve badge space without intrinsic-size restrictions in chips or dialogs.
class VerifiedNameLabel extends StatelessWidget {
  final Text child;
  final String? expiresAt;
  const VerifiedNameLabel(
      {super.key, required this.child, required this.expiresAt});
  @override
  Widget build(BuildContext context) {
    final end = DateTime.tryParse(expiresAt ?? '');
    if (end == null || !end.isAfter(DateTime.now())) return child;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: child.textDirection ?? Directionality.of(context),
      children: [Flexible(child: child), VerifiedBadge(expiresAt: expiresAt)],
    );
  }
}
