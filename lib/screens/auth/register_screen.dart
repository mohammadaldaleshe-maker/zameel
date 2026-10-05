import 'package:zameel/theme/appearance_controller.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';
import '../../main.dart';
import 'login_screen.dart';
import 'package:zameel/theme/app_theme.dart';

// ============================================================
// COLORS
// ============================================================
const Color primaryColor = AppTheme.primary;
const Color gradientStart = AppTheme.primary;
const Color gradientEnd = AppTheme.primaryDark;

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
    AppearanceScope.observe(context);
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.adaptiveGlassFill,
            AppTheme.adaptiveGlassSoft,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppTheme.adaptiveGlassBorder,
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
// REGISTER SCREEN
// ============================================================

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ============================================================
  // REGISTER
  // ============================================================
  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      Fluttertoast.showToast(
        msg: '❌ الرجاء ملء جميع الحقول',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (password.length < 6) {
      Fluttertoast.showToast(
        msg: '❌ كلمة المرور يجب أن تكون 6 أحرف على الأقل',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
        },
      );

      if (response.user != null) {
        if (!mounted) return;

        Fluttertoast.showToast(
          msg: '📩 تم إرسال رمز التحقق إلى بريدك الإلكتروني',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailOtpScreen(
              email: email,
              name: name,
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      Fluttertoast.showToast(
        msg: '❌ ${e.message}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ فشل إنشاء الحساب: ${e.toString()}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      kToolbarHeight -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_add_rounded,
                        size: 40,
                        color: AppTheme.legacyForeground,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title
                    Text(
                      isArabic ? 'إنشاء حساب جديد' : 'Create Account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.legacyForeground,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      isArabic
                          ? 'انضم إلى مجتمع Zameel'
                          : 'Join the Zameel community',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.legacySecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 30),

                    // Name
                    GlassContainer(
                      child: TextField(
                        controller: _nameController,
                        style: TextStyle(color: AppTheme.legacyForeground),
                        decoration: InputDecoration(
                          labelText: isArabic ? 'الاسم الكامل' : 'Full Name',
                          labelStyle:
                              TextStyle(color: AppTheme.legacySecondary),
                          prefixIcon: Icon(
                            Icons.person_rounded,
                            color: AppTheme.legacySecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppTheme.adaptiveGlassSoft,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Email
                    GlassContainer(
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: AppTheme.legacyForeground),
                        decoration: InputDecoration(
                          labelText: isArabic ? 'البريد الإلكتروني' : 'Email',
                          labelStyle:
                              TextStyle(color: AppTheme.legacySecondary),
                          prefixIcon: Icon(
                            Icons.email_rounded,
                            color: AppTheme.legacySecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppTheme.adaptiveGlassSoft,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Password
                    GlassContainer(
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: AppTheme.legacyForeground),
                        decoration: InputDecoration(
                          labelText: isArabic ? 'كلمة المرور' : 'Password',
                          labelStyle:
                              TextStyle(color: AppTheme.legacySecondary),
                          prefixIcon: Icon(
                            Icons.lock_rounded,
                            color: AppTheme.legacySecondary,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: AppTheme.legacySecondary,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppTheme.adaptiveGlassSoft,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Register Button
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 5,
                            ),
                            child: Text(
                              isArabic ? '📝 إنشاء حساب' : '📝 Create Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                    const SizedBox(height: 20),

                    // Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isArabic
                              ? 'لديك حساب بالفعل؟'
                              : 'Already have an account?',
                          style: TextStyle(
                            color: AppTheme.legacySecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: Text(
                            isArabic ? 'تسجيل الدخول' : 'Login',
                            style: TextStyle(
                              color: AppTheme.legacyForeground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EMAIL OTP SCREEN
// ============================================================

class EmailOtpScreen extends StatefulWidget {
  final String email;
  final String name;

  const EmailOtpScreen({
    super.key,
    required this.email,
    required this.name,
  });

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;

  // ============================================================
  // VERIFY OTP
  // ============================================================
  Future<void> _verifyOtp() async {
    final token = _otpController.text.trim();

    if (token.length != 6) {
      Fluttertoast.showToast(
        msg: '❌ أدخل رمز التحقق المكون من 6 أرقام',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: token,
        type: OtpType.signup,
      );

      if (response.user != null) {
        if (!mounted) return;

        Fluttertoast.showToast(
          msg: '✅ تم التحقق من البريد الإلكتروني بنجاح!',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        // بعد التحقق ننتقل إلى اختيار الجامعة
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const UniversityScreen(),
          ),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      Fluttertoast.showToast(
        msg: '❌ ${e.message}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ حدث خطأ أثناء التحقق: ${e.toString()}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // RESEND OTP
  // ============================================================
  Future<void> _resendOtp() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (!mounted) return;

      Fluttertoast.showToast(
        msg: '📩 تم إرسال رمز تحقق جديد إلى بريدك',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } on AuthException catch (e) {
      Fluttertoast.showToast(
        msg: '❌ ${e.message}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ تعذر إعادة إرسال الرمز',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
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
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    // Icon
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_email_read_rounded,
                        size: 45,
                        color: AppTheme.legacyForeground,
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Title
                    Text(
                      isArabic
                          ? 'تأكيد البريد الإلكتروني'
                          : 'Verify Your Email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.legacyForeground,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Description
                    Text(
                      isArabic
                          ? 'أرسلنا رمز تحقق مكونًا من 6 أرقام إلى'
                          : 'We sent a 6-digit verification code to',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.legacySecondary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Email
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.legacyForeground,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // OTP Field
                    GlassContainer(
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: TextStyle(
                          color: AppTheme.legacyForeground,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 10,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          labelText:
                              isArabic ? 'رمز التحقق' : 'Verification Code',
                          labelStyle:
                              TextStyle(color: AppTheme.legacySecondary),
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: AppTheme.legacySecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppTheme.adaptiveGlassSoft,
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Verify Button
                    _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : ElevatedButton(
                            onPressed: _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 5,
                            ),
                            child: Text(
                              isArabic ? '✅ تأكيد الرمز' : '✅ Verify Code',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                    const SizedBox(height: 20),

                    // Resend
                    TextButton(
                      onPressed: _isResending ? null : _resendOtp,
                      child: _isResending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isArabic
                                  ? '📩 إعادة إرسال الرمز'
                                  : '📩 Resend Code',
                              style: TextStyle(
                                color: AppTheme.legacyForeground,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),

                    const SizedBox(height: 10),

                    // Back to login
                    TextButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: Text(
                        isArabic ? 'العودة إلى تسجيل الدخول' : 'Back to Login',
                        style: TextStyle(
                          color: AppTheme.legacySecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
