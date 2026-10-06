import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});
  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int _step = 0;
  bool _busy = false;
  bool _verified = false;
  bool _completed = false;
  String? _error;
  DateTime? _lastSent;
  String? _verifiedUser;
  SupabaseClient get _db => Supabase.instance.client;

  Future<void> _send() async {
    if (_lastSent != null &&
        DateTime.now().difference(_lastSent!).inSeconds < 60) {
      setState(() => _error = 'انتظر دقيقة قبل إعادة إرسال الرمز');
      return;
    }
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'أدخل بريدًا إلكترونيًا صحيحًا');
      return;
    }
    await _run(() async {
      await _db.auth.resetPasswordForEmail(email);
      _lastSent = DateTime.now();
      if (mounted) setState(() => _step = 1);
    });
  }

  Future<void> _verify() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'أدخل رمز التحقق المكوّن من 6 أرقام');
      return;
    }
    await _run(() async {
      final result = await _db.auth.verifyOTP(
          email: _email.text.trim().toLowerCase(),
          token: _code.text.trim(),
          type: OtpType.recovery);
      if (result.session == null || result.user == null)
        throw StateError('No recovery session');
      _verified = true;
      _verifiedUser = result.user!.id;
      if (mounted) setState(() => _step = 2);
    });
  }

  Future<void> _save() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'كلمة المرور يجب أن تتكوّن من 8 أحرف على الأقل');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }
    await _run(() async {
      if (!_verified || _db.auth.currentUser?.id != _verifiedUser)
        throw StateError('Recovery expired');
      await _db.auth.updateUser(UserAttributes(password: _password.text));
      // Do not leave an abandoned recovery session logged in.
      await _db.auth.signOut(scope: SignOutScope.local);
      _completed = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'تم تغيير كلمة المرور. سجّل الدخول بكلمة المرور الجديدة')));
        Navigator.pop(context);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted)
        setState(() => _error = _step == 1
            ? 'الرمز غير صحيح أو انتهت صلاحيته. أعد المحاولة'
            : 'تعذر إكمال العملية. تحقق من الإنترنت وحاول مجددًا');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    if (_verified && !_completed && _db.auth.currentUser?.id == _verifiedUser) {
      _db.auth.signOut(scope: SignOutScope.local);
    }
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: Scaffold(
          appBar: AppBar(title: const Text('استعادة كلمة المرور')),
          body: ListView(padding: const EdgeInsets.all(24), children: [
            Text(_step == 0
                ? 'أدخل البريد الإلكتروني المسجّل في زميل'
                : _step == 1
                    ? 'إذا كان البريد مسجّلًا فسيصلك رمز تحقق. أدخله هنا'
                    : 'أدخل كلمة المرور الجديدة'),
            const SizedBox(height: 20),
            if (_step == 0)
              TextField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'البريد الإلكتروني')),
            if (_step == 1) ...[
              TextField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'رمز التحقق')),
              TextButton(
                  onPressed: _busy ? null : _send,
                  child: const Text('إعادة إرسال الرمز')),
            ],
            if (_step == 2) ...[
              TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'كلمة المرور الجديدة')),
              TextField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'تأكيد كلمة المرور')),
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: _busy
                    ? null
                    : (_step == 0
                        ? _send
                        : _step == 1
                            ? _verify
                            : _save),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_step == 0
                        ? 'إرسال رمز التحقق'
                        : _step == 1
                            ? 'تحقق'
                            : 'حفظ كلمة المرور')),
          ])));
}
