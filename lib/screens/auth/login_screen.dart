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

// ============================================================
// COLORS
// ============================================================
const Color primaryColor = Color(0xFF18D3C3);
const Color secondaryColor = Color(0xFF0B9F95);
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
// LOGIN SCREEN
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;


  // ============================================================
  // تحديد الصفحة التي يذهب إليها المستخدم بعد تسجيل الدخول
  // ============================================================

  Future<void> _goAfterLogin(String userId) async {
    try {
      final profile = await Supabase.instance.client
          .from('users')
          .select('university, college, department')
          .eq('id', userId)
          .maybeSingle();

      // ========================================================
      // المستخدم لا يملك ملفاً أو بياناته غير مكتملة
      // نرسله لإكمال اختيار الجامعة والكلية والقسم
      // ========================================================

      if (profile == null ||
          profile['university'] == null ||
          profile['college'] == null ||
          profile['department'] == null ||
          profile['university'].toString().trim().isEmpty ||
          profile['college'].toString().trim().isEmpty ||
          profile['department'].toString().trim().isEmpty) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const UniversityScreen(),
          ),
        );

        return;
      }

      // ========================================================
      // بيانات المستخدم موجودة
      // ========================================================

      final universityName =
          profile['university'].toString().trim();

      final collegeName =
          profile['college'].toString().trim();

      final departmentName =
          profile['department'].toString().trim();

      // ========================================================
      // البحث عن الجامعة المحفوظة
      // ========================================================

      final university = universities.firstWhere(
        (u) => u.name == universityName,
        orElse: () {
          throw Exception(
            'University not found: $universityName',
          );
        },
      );

      // ========================================================
      // البحث عن الكلية المحفوظة
      // ========================================================

      final college = university.colleges.firstWhere(
        (c) => c.name == collegeName,
        orElse: () {
          throw Exception(
            'College not found: $collegeName',
          );
        },
      );

      // ========================================================
      // الانتقال مباشرة إلى الصفحة الرئيسية
      // ========================================================

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeFeedScreen(
            university: university,
            college: college,
            department: departmentName,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Error checking user profile: $e',
      );

      if (!mounted) return;

      // ========================================================
      // في حال وجود مشكلة في بيانات المستخدم
      // نرسله لإكمال بيانات الجامعة
      // ========================================================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const UniversityScreen(),
        ),
      );
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Fluttertoast.showToast(
        msg: '❌ الرجاء إدخال البريد الإلكتروني وكلمة المرور',
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

      final response = await Supabase.instance.client.auth
          .signInWithPassword(
        email: email,
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
        msg: '❌ فشل تسجيل الدخول: ${e.toString()}',
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
    final languageProvider =
        Provider.of<LanguageProvider>(context);

    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
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
            icon: const Icon(
              Icons.arrow_back_rounded,
            ),
          ),
        ),

        // ======================================================
        // BODY
        // ======================================================

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 30),

              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,

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
                      child: Image.asset('assets/branding/zameel_mark.png', fit: BoxFit.contain),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // TITLE
                  // ==================================================

                  Text(
                    isArabic
                        ? 'مرحباً بعودتك!'
                        : 'Welcome Back!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ==================================================
                  // SUBTITLE
                  // ==================================================

                  Text(
                    isArabic
                        ? 'سجل الدخول للاستمرار'
                        : 'Login to continue',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // EMAIL
                  // ==================================================

                  GlassContainer(
                    child: TextField(
                      controller: _emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        labelText: isArabic
                            ? 'البريد الإلكتروني'
                            : 'Email',
                        labelStyle:
                            const TextStyle(
                          color: Colors.white70,
                        ),
                        prefixIcon: const Icon(
                          Icons.email_rounded,
                          color: Colors.white70,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            Colors.white.withAlpha(25),
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
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        labelText: isArabic
                            ? 'كلمة المرور'
                            : 'Password',
                        labelStyle:
                            const TextStyle(
                          color: Colors.white70,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white70,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword =
                                  !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            color: Colors.white70,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            Colors.white.withAlpha(25),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // LOGIN BUTTON / LOADING
                  // ==================================================

                  _isLoading
                      ? const Center(
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _login,
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                primaryColor,
                            foregroundColor:
                                Colors.white,
                            minimumSize:
                                const Size(
                              double.infinity,
                              55,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(30),
                            ),
                            elevation: 5,
                          ),
                          child: Text(
                            isArabic
                                ? '🔑 تسجيل الدخول'
                                : '🔑 Login',
                            style:
                                const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // CREATE ACCOUNT
                  // ==================================================

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        isArabic
                            ? 'ليس لديك حساب؟'
                            : "Don't have an account?",
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),

                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const RoleSelectionScreen()
                            ),
                          );
                        },
                        child: Text(
                          isArabic
                              ? 'إنشاء حساب'
                              : 'Create Account',
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontWeight:
                                FontWeight.bold,
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
    );
  }
}
