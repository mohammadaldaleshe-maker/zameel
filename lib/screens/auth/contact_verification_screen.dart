import '../../services/jordan_phone.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import 'profile_picture_screen.dart';

class ContactVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ContactVerificationScreen({super.key, required this.userData});

  @override
  State<ContactVerificationScreen> createState() =>
      _ContactVerificationScreenState();
}

class _ContactVerificationScreenState extends State<ContactVerificationScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  int _resendSeconds = 0;
  Timer? _timer;

  String get _method => 'email';
  String get _email =>
      (widget.userData['email'] ?? '').toString().trim().toLowerCase();
  String get _phone =>
      _normalizePhone((widget.userData['phone'] ?? '').toString());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  String _normalizePhone(String input) => normalizeJordanMobile(input) ?? '';

  void _message(String text, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor:
              success ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _start({bool resend = false}) async {
    if (_busy || (_sent && !resend)) return;
    setState(() => _busy = true);
    try {
      final current = Supabase.instance.client.auth.currentUser;
      if (current != null) {
        await _finish(current);
        return;
      }
      if (resend) {
        await Supabase.instance.client.auth.resend(
          type: _method == 'phone' ? OtpType.sms : OtpType.signup,
          email: _method == 'email' ? _email : null,
          phone: _method == 'phone' ? _phone : null,
        );
        if (mounted) {
          setState(() => _sent = true);
          _startCountdown();
          _message('تم إرسال رمز تحقق جديد.', success: true);
        }
        return;
      }
      final password = (widget.userData['password'] ?? '').toString();
      final metadata = <String, dynamic>{
        'name': widget.userData['fullDisplayName'],
        'email': _email,
        'phone': _phone,
        'role': widget.userData['role'],
        'gender': widget.userData['gender'],
        'registration': {...widget.userData}..remove('password'),
      };
      AuthResponse response;
      if (_method == 'phone') {
        if (!RegExp(r'^\+9627[789]\d{7}$').hasMatch(_phone)) {
          throw const AuthException('أدخل رقمًا أردنيًا صحيحًا يبدأ بـ 07.');
        }
        response = await Supabase.instance.client.auth.signUp(
          phone: _phone,
          password: password,
          data: metadata,
        );
      } else {
        response = await Supabase.instance.client.auth.signUp(
          email: _email,
          password: password,
          data: metadata,
        );
      }

      if (!mounted) return;
      if (response.session != null && response.user != null) {
        await _finish(response.user!);
        return;
      }
      setState(() => _sent = true);
      _startCountdown();
      _message(
        _method == 'phone'
            ? 'تم إرسال رمز التحقق إلى رقم الهاتف.'
            : 'تم إرسال رمز التحقق إلى البريد الإلكتروني.',
        success: true,
      );
    } on AuthException catch (error) {
      _message(_friendlyError(error.message));
    } catch (_) {
      _message('تعذر إرسال رمز التحقق. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _verify() async {
    if (_busy || !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      _message('أدخل رمز التحقق المكوّن من 6 أرقام.');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        type: _method == 'phone' ? OtpType.sms : OtpType.signup,
        token: _code.text.trim(),
        email: _method == 'email' ? _email : null,
        phone: _method == 'phone' ? _phone : null,
      );
      if (response.user == null) throw const AuthException('تعذر تأكيد الرمز.');
      await _finish(response.user!);
    } on AuthException catch (error) {
      _message(_friendlyError(error.message));
    } catch (_) {
      _message(
        'تعذر حفظ بيانات التسجيل. يمكنك إعادة المحاولة دون إنشاء حساب جديد.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish(User user) async {
    final raw = widget.userData['fullName'];
    final names = raw is Map ? raw : <String, dynamic>{};
    await Supabase.instance.client.rpc(
      'zameel_complete_registration',
      params: {
        'p_data': {
          'first_name': names['firstName'],
          'father_name': names['fatherName'],
          'family_name': names['familyName'],
          'account_type': widget.userData['accountType'] ?? 'general',
          'display_name_format':
              widget.userData['displayNameFormat'] ?? 'first_family',
          'gender': widget.userData['gender'],
          'phone': _phone,
          'email': _email,
          'verification_method': _method,
          'university': widget.userData['university'],
          'college': widget.userData['college'],
          'major': widget.userData['department'],
          'academic_degree': widget.userData['academicDegree'],
          'student_number': widget.userData['studentNumber'],
        },
      },
    );
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfilePictureScreen(
          userData: {...widget.userData, 'supabase_user_id': user.id},
        ),
      ),
      (_) => false,
    );
  }

  String _friendlyError(String message) {
    final value = message.toLowerCase();
    if (value.contains('already'))
      return 'رقم الهاتف أو البريد مستخدم في حساب آخر.';
    if (value.contains('rate'))
      return 'محاولات كثيرة. انتظر قليلًا ثم أعد المحاولة.';
    if (value.contains('otp') || value.contains('token'))
      return 'الرمز غير صحيح أو انتهت صلاحيته.';
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final target = _method == 'phone' ? _phone : _email;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تأكيد الحساب')),
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.signatureGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _method == 'phone'
                              ? Icons.sms_rounded
                              : Icons.mark_email_read_rounded,
                          size: 64,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'أدخل رمز التحقق',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(target, textDirection: TextDirection.ltr),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _code,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'رمز من 6 أرقام',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _verify,
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('تأكيد وإكمال التسجيل'),
                          ),
                        ),
                        TextButton(
                          onPressed: _resendSeconds == 0 && !_busy
                              ? () => _start(resend: true)
                              : null,
                          child: Text(
                            _resendSeconds == 0
                                ? (Supabase.instance.client.auth.currentUser !=
                                        null
                                    ? 'إعادة محاولة إكمال التسجيل'
                                    : 'إعادة إرسال الرمز')
                                : 'إعادة الإرسال بعد $_resendSeconds ثانية',
                          ),
                        ),
                      ],
                    ),
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
