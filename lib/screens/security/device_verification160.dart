import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/device_trust160.dart';
import '../../services/auth_session_service.dart';

class DeviceVerification160 extends StatefulWidget {
  const DeviceVerification160({super.key, required this.onVerified});
  final VoidCallback onVerified;
  @override
  State<DeviceVerification160> createState() => _DeviceVerification160State();
}

class _DeviceVerification160State extends State<DeviceVerification160> {
  final _code = TextEditingController();
  late final user = Supabase.instance.client.auth.currentUser!;
  String? _challenge, _error;
  bool _busy = false;
  int _seconds = 0;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted)
        setState(() => _error = e is AuthException &&
                (e.statusCode == '429' ||
                    e.code == 'over_email_send_rate_limit')
            ? 'تم إرسال طلبات كثيرة. انتظر قليلًا ثم حاول مجددًا.'
            : 'تعذر إتمام التحقق. تأكد من الرمز والاتصال، أو أعد إرسال رمز جديد.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
        if (_seconds > 0) return;
        final challenge = await DeviceTrust160.sendCode();
        if (!mounted) return;
        setState(() {
          _challenge = challenge;
          _seconds = 60;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted || _seconds <= 1) {
            t.cancel();
            if (mounted) setState(() => _seconds = 0);
          } else {
            setState(() => _seconds--);
          }
        });
      });
  Future<void> _verify() => _run(() async {
        if (_challenge == null ||
            !RegExp(r'^\d{6,10}$').hasMatch(_code.text.trim())) {
          setState(() => _error = 'أدخل رمز التحقق المرسل إلى بريدك.');
          return;
        }
        await DeviceTrust160.verify(
            user.emailConfirmedAt != null ? user.email! : user.phone!,
            _challenge!,
            _code.text,
            user.id,
            phone: user.emailConfirmedAt == null);
        if (mounted) widget.onVerified();
      });
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تأكيد الجهاز')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Icon(Icons.phonelink_lock, size: 56),
                      const SizedBox(height: 16),
                      const Text(
                          'للحفاظ على حسابك، أكّد هذا الجهاز برمز يصلك إلى بريدك الإلكتروني، أو رقمك المؤكد للحسابات المسجلة بالهاتف.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(
                          user.emailConfirmedAt != null
                              ? user.email ?? ''
                              : user.phone ?? '',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _busy || _seconds > 0 ? null : _send,
                          child: Text(_seconds > 0
                              ? 'إعادة الإرسال بعد $_seconds ثانية'
                              : _challenge == null
                                  ? 'إرسال رمز التحقق'
                                  : 'إرسال رمز جديد')),
                      if (_challenge != null) ...[
                        const SizedBox(height: 16),
                        TextField(
                            controller: _code,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            textDirection: TextDirection.ltr,
                            decoration:
                                const InputDecoration(labelText: 'رمز التحقق'),
                            onSubmitted: (_) {
                              if (!_busy) _verify();
                            }),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _busy ? null : _verify,
                            child: const Text('تأكيد الجهاز والدخول')),
                      ],
                      if (_busy)
                        const Center(
                            child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator())),
                      if (_error != null)
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await AuthSessionService.signOut();
                                },
                          child: const Text('تسجيل الخروج')),
                    ]))),
      ));
}
