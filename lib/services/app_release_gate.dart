import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// These values are verified against pubspec by the release contract test.
const zameelVersion = '2.0.14';
const zameelBuild = 23;

class AppReleaseGate extends StatefulWidget {
  const AppReleaseGate({super.key, required this.child});
  final Widget child;
  @override
  State<AppReleaseGate> createState() => _AppReleaseGateState();
}

class _AppReleaseGateState extends State<AppReleaseGate>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _policy;
  Timer? _timer;
  bool _checking = false;
  String get _platform => kIsWeb
      ? 'web'
      : defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
  String get _cacheKey => 'zameel_release_policy_$_platform';
  bool get _blocked => _policy?['allowed'] == false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
    _check();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _check());
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_cacheKey);
      if (value != null && mounted && _policy == null) {
        final cached = Map<String, dynamic>.from(jsonDecode(value) as Map);
        // Policies saved by a previous installed build cannot block an upgrade.
        if (cached['checked_build'] == zameelBuild)
          setState(() => _policy = cached);
      }
    } catch (_) {}
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final value = await Supabase.instance.client.rpc('zameel_release_policy',
          params: {
            'p_platform': _platform,
            'p_build': zameelBuild
          }).timeout(const Duration(seconds: 8));
      final policy = Map<String, dynamic>.from(value as Map)
        ..['checked_build'] = zameelBuild;
      if (mounted) setState(() => _policy = policy);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(policy));
    } catch (_) {
      // A failed request does not invent a block or erase a confirmed block.
    } finally {
      _checking = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _update() async {
    final url = Uri.tryParse('${_policy?['download_url'] ?? ''}');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) return;
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر فتح رابط التحديث')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_blocked) return widget.child;
    return PopScope(
        canPop: false,
        child: Scaffold(
            body: SafeArea(
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.system_update, size: 64),
                          const SizedBox(height: 20),
                          const Text('يجب تحديث التطبيق للمتابعة',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          Text(
                              'الإصدار المعتمد: ${_policy?['version_name'] ?? ''}'),
                          const SizedBox(height: 20),
                          FilledButton(
                              onPressed: _update,
                              child: const Text('تحديث التطبيق')),
                          TextButton(
                              onPressed: _check,
                              child: const Text('إعادة التحقق')),
                        ]))))));
  }
}
