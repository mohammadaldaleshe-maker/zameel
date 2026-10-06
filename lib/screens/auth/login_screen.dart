import 'package:url_launcher/url_launcher.dart';
import 'password_recovery_screen.dart';
import 'package:zameel/theme/appearance_controller.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';
import '../../main.dart';
import 'register_screen.dart';
import 'role_selection_screen.dart';

import 'package:zameel/theme/app_theme.dart';

// ============================================================
// COLORS
// ============================================================
const Color primaryColor = AppTheme.primary;
const Color secondaryColor = AppTheme.primaryDark;
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
          colors: [AppTheme.adaptiveGlassFill, AppTheme.adaptiveGlassSoft],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppTheme.adaptiveGlassBorder, width: 1.5),
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
// LOGIN SCREEN
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ============================================================
  // تحديد الصفحة التي يذهب إليها المستخدم بعد تسجيل الدخول
  // ============================================================

  Future<void> _goAfterLogin(String userId) async {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  Future<void> _login() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      Fluttertoast.showToast(
        msg: '❌ أدخل البريد الإلكتروني أو رقم الهاتف وكلمة المرور',
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
      // ========================================================
      // SUPABASE LOGIN
      // ========================================================

      var normalizedPhone = identifier.replaceAll(RegExp(r'[^0-9+]'), '');
      if (normalizedPhone.startsWith('00962'))
        normalizedPhone = '+962${normalizedPhone.substring(5)}';
      if (normalizedPhone.startsWith('07'))
        normalizedPhone = '+962${normalizedPhone.substring(1)}';
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: identifier.contains('@') ? identifier.toLowerCase() : null,
        phone: identifier.contains('@') ? null : normalizedPhone,
        password: password,
      );

      // ========================================================
      // LOGIN SUCCESS
      // ========================================================

      if (response.user != null) {
        Fluttertoast.showToast(
          msg: '✅ تم تسجيل الدخول بنجاح!',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        // ======================================================
        // فحص بيانات المستخدم وتحديد الصفحة المناسبة
        // ======================================================

        await _goAfterLogin(response.user!.id);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: e is AuthException && e.code == 'invalid_credentials'
            ? 'البريد الإلكتروني أو رقم الهاتف أو كلمة المرور غير صحيحة'
            : e is AuthException && e.code == 'email_not_confirmed'
                ? 'يرجى تأكيد بريدك الإلكتروني أولًا'
                : e is AuthException &&
                        (e.statusCode == '429' ||
                            e.code == 'over_request_rate_limit')
                    ? 'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا'
                    : 'تعذر تسجيل الدخول. تحقق من اتصال الإنترنت وحاول مجددًا',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

        // ======================================================
        // APP BAR
        // ======================================================
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

        // ======================================================
        // BODY
        // ======================================================
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradientStart, gradientEnd],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ==================================================
                    // ICON
                    // ==================================================

                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/branding/zameel_mark.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // TITLE
                    // ==================================================
                    Text(
                      isArabic ? 'مرحباً بعودتك!' : 'Welcome Back!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.legacyForeground,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ==================================================
                    // SUBTITLE
                    // ==================================================
                    Text(
                      isArabic ? 'سجل الدخول للاستمرار' : 'Login to continue',
                      style: TextStyle(
                          fontSize: 14, color: AppTheme.legacySecondary),
                    ),

                    const SizedBox(height: 30),

                    // ==================================================
                    // EMAIL
                    // ==================================================
                    GlassContainer(
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: AppTheme.legacyForeground),
                        decoration: InputDecoration(
                          labelText: isArabic
                              ? 'البريد الإلكتروني أو رقم الهاتف'
                              : 'Email or phone number',
                          labelStyle:
                              TextStyle(color: AppTheme.legacySecondary),
                          prefixIcon: Icon(
                            Icons.alternate_email_rounded,
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

                    // ==================================================
                    // PASSWORD
                    // ==================================================
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

                    // ==================================================
                    // LOGIN BUTTON / LOADING
                    // ==================================================
                    _isLoading
                        ? Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          )
                        : ElevatedButton(
                            onPressed: _login,
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
                              isArabic ? '🔑 تسجيل الدخول' : '🔑 Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // CREATE ACCOUNT
                    // ==================================================
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const PasswordRecoveryScreen())),
                            child: Text(
                                isArabic
                                    ? 'نسيت كلمة المرور؟'
                                    : 'Forgot password?',
                                style: const TextStyle(color: Colors.white))),
                        TextButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    try {
                                      final text = Uri.encodeComponent(
                                          'مرحبًا، أحتاج مساعدة في تطبيق زميل');
                                      var opened = false;
                                      try {
                                        opened = await launchUrl(
                                            Uri.parse(
                                                'whatsapp://send?phone=962792009821&text=$text'),
                                            mode:
                                                LaunchMode.externalApplication);
                                      } catch (_) {}
                                      if (!opened)
                                        opened = await launchUrl(
                                            Uri.parse(
                                                'https://wa.me/962792009821?text=$text'),
                                            mode:
                                                LaunchMode.externalApplication);
                                      if (!opened && mounted)
                                        Fluttertoast.showToast(
                                            msg: 'تعذر فتح واتساب');
                                    } catch (_) {
                                      if (mounted)
                                        Fluttertoast.showToast(
                                            msg: 'تعذر فتح واتساب');
                                    }
                                  },
                            child: Text(
                                isArabic ? 'تواصل مع الدعم' : 'Contact support',
                                style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isArabic
                              ? 'ليس لديك حساب؟'
                              : "Don't have an account?",
                          style: TextStyle(color: AppTheme.legacySecondary),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RoleSelectionScreen(),
                              ),
                            );
                          },
                          child: Text(
                            isArabic ? 'إنشاء حساب' : 'Create Account',
                            style: TextStyle(
                              color: AppTheme.legacyForeground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
