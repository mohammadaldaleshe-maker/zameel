import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/language_provider.dart';
import 'profile_picture_screen.dart';

// ============================================================
// COLORS
// ============================================================

const Color primaryColor = Color(0xFF18D3C3);
const Color gradientStart = Color(0xFF18D3C3);
const Color gradientEnd = Color(0xFF0B9F95);

// ============================================================
// GLASS CONTAINER
// ============================================================

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x33FFFFFF),
            Color(0x1AFFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0x66FFFFFF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ============================================================
// EMAIL VERIFICATION SCREEN
// ============================================================

class EmailVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EmailVerificationScreen({
    super.key,
    required this.userData,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<EmailVerificationScreen> {
  final TextEditingController _codeController =
      TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;

  int _resendCountdown = 0;
  Timer? _countdownTimer;

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  static final RegExp _emailRegex = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  );

  static const Set<String> _blockedTemporaryDomains = {
    '10minutemail.com',
    '10minutemail.net',
    'guerrillamail.com',
    'guerrillamail.net',
    'guerrillamail.org',
    'mailinator.com',
    'tempmail.com',
    'temp-mail.org',
    'temp-mail.io',
    'throwawaymail.com',
    'yopmail.com',
    'getnada.com',
    'emailondeck.com',
    'fakeinbox.com',
    'maildrop.cc',
    'dispostable.com',
    'sharklasers.com',
    'grr.la',
    'guerrillamailblock.com',
  };

  String get _email {
    return (widget.userData['email'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }

  String? _validateEmail(String email) {
    final value = email.trim();

    if (value.isEmpty) {
      return 'الرجاء إدخال البريد الإلكتروني';
    }

    if (!RegExp(r'^[\x00-\x7F]+$').hasMatch(value)) {
      return 'البريد الإلكتروني يجب أن يحتوي على أحرف إنجليزية فقط';
    }

    if (value.contains(' ')) {
      return 'البريد الإلكتروني لا يمكن أن يحتوي على مسافات';
    }

    if (!_emailRegex.hasMatch(value)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    if (value.length > 254) {
      return 'البريد الإلكتروني طويل جداً';
    }

    final parts = value.split('@');

    if (parts.length != 2) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    final localPart = parts[0];
    final domain = parts[1];

    if (localPart.isEmpty || domain.isEmpty) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    if (localPart.startsWith('.') ||
        localPart.endsWith('.')) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    if (localPart.contains('..') ||
        domain.contains('..')) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    if (!domain.contains('.')) {
      return 'نطاق البريد الإلكتروني غير صحيح';
    }

    if (_blockedTemporaryDomains.contains(domain)) {
      return 'البريد الإلكتروني المؤقت غير مسموح به';
    }

    return null;
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
          ),
          backgroundColor: success
              ? Colors.green.shade700
              : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ============================================================
  // SEND / RESEND VERIFICATION CODE
  // ============================================================

  Future<void> _sendVerificationCode({
  bool isResend = false,
}) async {
  final emailError = _validateEmail(_email);

  if (emailError != null) {
    _showMessage(emailError);
    return;
  }

  if (isResend) {
    // في وضع الاختبار لا نحتاج OTP.
    _showMessage(
      'التحقق بالبريد معطل حاليًا في وضع التطوير.',
      success: true,
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final password =
        (widget.userData['password'] ?? '').toString();

    if (password.isEmpty) {
      throw const AuthException(
        'بيانات التسجيل غير مكتملة. كلمة المرور غير موجودة.',
      );
    }

    final supabase = Supabase.instance.client;

    final response = await supabase.auth.signUp(
      email: _email,
      password: password,
      data: {
        'email': _email,
      },
    );

    if (!mounted) return;

    final user = response.user;

    if (user == null) {
      throw const AuthException(
        'تعذر إنشاء حساب التسجيل.',
      );
    }

    // ========================================================
    // Confirm email = OFF
    // ========================================================

    if (response.session != null) {
      final rawFullName = widget.userData['fullName'];

      final Map<String, dynamic> fullName =
          rawFullName is Map
              ? Map<String, dynamic>.from(rawFullName)
              : <String, dynamic>{};

      final firstName =
          (fullName['firstName'] ?? '').toString().trim();

      final fatherName =
          (fullName['fatherName'] ?? '').toString().trim();

      final grandfatherName =
          (fullName['grandfatherName'] ?? '').toString().trim();

      final familyName =
          (fullName['familyName'] ?? '').toString().trim();

      final nameParts = [
        firstName,
        fatherName,
        grandfatherName,
        familyName,
      ].where((part) => part.isNotEmpty).toList();

      final fullNameText =
          nameParts.isEmpty ? 'مستخدم' : nameParts.join(' ');

      await supabase.from('users').upsert(
        {
          'id': user.id,
          'email': user.email ?? _email,
          'name': fullNameText,
          'university':
              (widget.userData['university'] ?? '').toString(),
          'college':
              (widget.userData['college'] ?? '').toString(),
          'department':
              (widget.userData['department'] ?? '').toString(),
        },
        onConflict: 'id',
      );

      _showMessage(
        'تم إنشاء الحساب وحفظ بياناتك بنجاح',
        success: true,
      );

      await Future.delayed(
        const Duration(milliseconds: 400),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfilePictureScreen(
            userData: {
              ...widget.userData,
              'email': _email,
              'supabase_user_id': user.id,
              'email_verified': false,
            },
          ),
        ),
      );

      return;
    }

    // ========================================================
    // إذا أعيد المستخدم بدون Session
    // فهذا يعني أن تأكيد البريد ما زال مطلوبًا.
    // ========================================================

    _showMessage(
      'تم إنشاء الحساب، ولكن ما زال تأكيد البريد الإلكتروني مطلوبًا.',
      success: true,
    );
  } on AuthException catch (e) {
    if (!mounted) return;

    _showMessage(
      _translateAuthError(e.message),
    );
  } catch (e) {
    if (!mounted) return;

    _showMessage(
      'حدث خطأ أثناء إنشاء الحساب. حاول مرة أخرى.',
    );

    debugPrint(
      'Registration error: $e',
    );
  } finally {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }
}

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _showMessage(
        'الرجاء إدخال رمز التحقق',
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage(
        'رمز التحقق يجب أن يتكون من 6 أرقام',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // ========================================================
      // VERIFY OTP
      // ========================================================

      final response = await supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: _email,
        token: code,
      );

      if (!mounted) return;

      final user = response.user;

      if (user == null) {
        throw const AuthException(
          'تعذر تأكيد البريد الإلكتروني.',
        );
      }

      // ========================================================
      // PREPARE FULL NAME SAFELY
      // ========================================================

      final rawFullName =
          widget.userData['fullName'];

      final Map<String, dynamic> fullName =
          rawFullName is Map
              ? Map<String, dynamic>.from(
                  rawFullName,
                )
              : <String, dynamic>{};

      final firstName =
          (fullName['firstName'] ?? '')
              .toString()
              .trim();

      final fatherName =
          (fullName['fatherName'] ?? '')
              .toString()
              .trim();

      final grandfatherName =
          (fullName['grandfatherName'] ?? '')
              .toString()
              .trim();

      final familyName =
          (fullName['familyName'] ?? '')
              .toString()
              .trim();

      final nameParts = [
        firstName,
        fatherName,
        grandfatherName,
        familyName,
      ].where((part) => part.isNotEmpty).toList();

      final fullNameText = nameParts.isEmpty
          ? 'مستخدم'
          : nameParts.join(' ');

      // ========================================================
      // SAVE USER PROFILE
      // ========================================================

      await supabase.from('users').upsert(
        {
          'id': user.id,
          'email': user.email ?? _email,
          'name': fullNameText,
          'university':
              (widget.userData['university'] ?? '')
                  .toString(),
          'college':
              (widget.userData['college'] ?? '')
                  .toString(),
          'department':
              (widget.userData['department'] ?? '')
                  .toString(),
        },
        onConflict: 'id',
      );

      // ========================================================
      // SUCCESS
      // ========================================================

      _showMessage(
        'تم تأكيد البريد الإلكتروني وحفظ بيانات الحساب بنجاح',
        success: true,
      );

      await Future.delayed(
        const Duration(milliseconds: 400),
      );

      if (!mounted) return;

      // ========================================================
      // GO TO PROFILE PICTURE
      // ========================================================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfilePictureScreen(
            userData: {
              ...widget.userData,
              'email': _email,
              'supabase_user_id': user.id,
              'email_verified': true,
            },
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      _showMessage(
        _translateAuthError(e.message),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'حدث خطأ أثناء تأكيد الحساب أو حفظ بيانات التسجيل. حاول مرة أخرى.',
      );

      debugPrint(
        'Registration error: $e',
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // SUPABASE ERROR TRANSLATION
  // ============================================================

  String _translateAuthError(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('already registered') ||
        lower.contains('already exists') ||
        lower.contains('user already')) {
      return 'هذا البريد الإلكتروني مستخدم بالفعل. لا يمكن إنشاء حسابين بنفس البريد.';
    }

    if (lower.contains('invalid email')) {
      return 'البريد الإلكتروني غير صالح.';
    }

    if (lower.contains('email rate limit')) {
      return 'تم تجاوز عدد محاولات إرسال الرموز. انتظر قليلاً ثم حاول مرة أخرى.';
    }

    if (lower.contains('rate limit')) {
      return 'تم تجاوز الحد المسموح للمحاولات. انتظر قليلاً ثم حاول مرة أخرى.';
    }

    if (lower.contains('invalid') &&
        lower.contains('otp')) {
      return 'رمز التحقق غير صحيح أو انتهت صلاحيته.';
    }

    if (lower.contains('expired')) {
      return 'انتهت صلاحية رمز التحقق. اطلب رمزاً جديداً.';
    }

    return message.isNotEmpty
        ? message
        : 'حدث خطأ غير متوقع.';
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context);

    final isArabic =
        languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradientStart,
                gradientEnd,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  Text(
                    isArabic
                        ? '📧 تأكيد البريد الإلكتروني'
                        : '📧 Email Verification',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    isArabic
                        ? 'أرسلنا رمز تحقق إلى بريدك الإلكتروني'
                        : 'We sent a verification code to your email',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 12),

                  GlassContainer(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _email,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  GlassContainer(
                    child: TextField(
                      controller: _codeController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        letterSpacing: 8,
                      ),
                      keyboardType:
                          TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: isArabic
                            ? '🔢 رمز التحقق'
                            : '🔢 Verification Code',
                        labelStyle:
                            const TextStyle(
                          color: Colors.white70,
                        ),
                        hintText: '123456',
                        hintStyle:
                            const TextStyle(
                          color: Colors.white38,
                          fontSize: 20,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            Colors.white.withAlpha(25),
                        counterText: '',
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _isLoading
                              ? null
                              : _verifyCode,
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.white,
                        foregroundColor:
                            primaryColor,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(
                                color: primaryColor,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isArabic
                                  ? '✅ تحقق'
                                  : '✅ Verify',
                              style:
                                  const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: TextButton(
                      onPressed:
                          (_isResending ||
                                  _resendCountdown > 0)
                              ? null
                              : () =>
                                  _sendVerificationCode(
                                    isResend: true,
                                  ),
                      child: Text(
                        _resendCountdown > 0
                            ? (isArabic
                                ? '🔄 إعادة الإرسال بعد $_resendCountdown ثانية'
                                : '🔄 Resend in $_resendCountdown seconds')
                            : (isArabic
                                ? '🔄 إعادة إرسال الرمز'
                                : '🔄 Resend Code'),
                        style: TextStyle(
                          color:
                              (_isResending ||
                                      _resendCountdown >
                                          0)
                                  ? Colors.white38
                                  : Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  Center(
                    child: Text(
                      isArabic
                          ? '⚠️ لم تصلك الرسالة؟ تحقق من مجلد البريد العشوائي (Spam)'
                          : "⚠️ Didn't receive the email? Check your spam folder",
                      style: TextStyle(
                        color:
                            Colors.white.withAlpha(179),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () =>
                            Navigator.pop(context),
                    child: Text(
                      isArabic
                          ? '↩ العودة'
                          : '↩ Back',
                      style:
                          const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
