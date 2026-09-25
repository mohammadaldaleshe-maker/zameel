import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Refreshes the administrative account state for an already signed-in user.
/// Supabase's auth ban alone does not expire an existing access token.
class AccountAccessMonitor extends StatefulWidget {
  const AccountAccessMonitor({super.key, required this.child});
  final Widget child;

  @override
  State<AccountAccessMonitor> createState() => _AccountAccessMonitorState();
}

class _AccountAccessMonitorState extends State<AccountAccessMonitor>
    with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<AuthState>? _subscription;
  Map<String, dynamic>? _decision;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (Supabase.instance.client.auth.currentUser == null && mounted) {
        setState(() => _decision = null);
      } else {
        _refresh();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_checking || !mounted) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      if (_decision != null) setState(() => _decision = null);
      return;
    }
    _checking = true;
    try {
      final rows = await client.rpc('get_my_account_access');
      if (!mounted || client.auth.currentUser?.id != userId) return;
      final row = rows is List && rows.isNotEmpty
          ? Map<String, dynamic>.from(rows.first as Map)
          : <String, dynamic>{};
      setState(() => _decision = row['allowed'] == false ||
              row['status'] == 'suspended' ? row : null);
    } catch (_) {
      // A network interruption must not quietly remove an existing block.
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;
    if (decision == null) return widget.child;
    final blocked = decision['status'] == 'blocked';
    final until = DateTime.tryParse(decision['suspended_until']?.toString() ?? '');
    final deadline = until == null
        ? 'غير محدد المدة'
        : 'حتى ${MaterialLocalizations.of(context).formatFullDate(until.toLocal())} '
          '${TimeOfDay.fromDateTime(until.toLocal()).format(context)}';
    if (!blocked && decision['status'] == 'suspended') {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Column(children: [
          Material(
            color: const Color(0xFFFFF1CE),
            child: SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text('حسابك معلّق للمشاهدة فقط. السبب: '
                  '${decision['reason'] ?? ''}. المدة: $deadline',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87)),
            )),
          ),
          Expanded(child: widget.child),
        ]),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: const Color(0xFFF6F8FA),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.info_outline_rounded, size: 56,
                          color: Color(0xFF0F8F87)),
                      const SizedBox(height: 16),
                      Text(blocked ? 'تم حظر حسابك في زميل' : 'تم تعليق حسابك في زميل',
                          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 16),
                      Text('السبب: ${decision['reason'] ?? ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 9),
                      Text('المدة: $deadline', textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 20),
                      OutlinedButton(onPressed: _refresh,
                          child: const Text('التحقق من الحالة مجددًا')),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
