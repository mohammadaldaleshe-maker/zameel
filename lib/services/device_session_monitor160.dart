import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'device_trust160.dart';
import 'auth_session_service.dart';

/// Server policies deny revoked sessions on each request. This monitor clears
/// already-loaded UI soon after revocation and whenever the app resumes.
class DeviceSessionMonitor160 extends StatefulWidget {
  const DeviceSessionMonitor160({super.key, required this.child});
  final Widget child;
  @override
  State<DeviceSessionMonitor160> createState() =>
      _DeviceSessionMonitor160State();
}

class _DeviceSessionMonitor160State extends State<DeviceSessionMonitor160>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false, _wasApproved = false;
  String? _user;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
    _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    final user = Supabase.instance.client.auth.currentUser?.id;
    if (user != _user) {
      _user = user;
      _wasApproved = false;
    }
    if (user == null) return;
    _checking = true;
    try {
      final status = await DeviceTrust160.status();
      if (Supabase.instance.client.auth.currentUser?.id != user) return;
      if (status['approved'] == true) {
        _wasApproved = true;
      } else if (_wasApproved || DeviceTrust160.approvedUser == user) {
        _wasApproved = false;
        await AuthSessionService.signOut();
      }
    } catch (_) {
      /* Network failure does not imply revocation; server remains authoritative. */
    } finally {
      _checking = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    if (state == AppLifecycleState.resumed) {
      _check();
      _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
