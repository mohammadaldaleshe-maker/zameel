import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/language_provider.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

// ============================================================
// COLORS
// ============================================================

const Color primaryColor = Color(0xFF18D3C3);
const Color gradientStart = Color(0xFF18D3C3);
const Color gradientEnd = Color(0xFF0B9F95);

// ============================================================
// WELCOME SCREEN
// ============================================================

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context);

    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection:
          isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 20,
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          // ==================================================
                          // LANGUAGE BUTTON
                          // ==================================================

                          Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(25),
                                borderRadius:
                                    BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withAlpha(70),
                                ),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  languageProvider.toggleLanguage();
                                },
                                icon: const Icon(
                                  Icons.language,
                                  color: Colors.white,
                                ),
                                tooltip: isArabic
                                    ? 'تغيير اللغة'
                                    : 'Change language',
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // ==================================================
                          // APP LOGO
                          // ==================================================

                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0x44FFFFFF),
                                  Color(0x22FFFFFF),
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withAlpha(100),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(35),
                                  blurRadius: 35,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Image.asset(
                                'assets/branding/zameel_mark.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // ==================================================
                          // APP NAME
                          // ==================================================

                          Text(
                            'Zameel',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            isArabic
                                ? 'منصة الطلاب الجامعيين'
                                : 'University Students Platform',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            isArabic
                                ? 'تعلّم، تواصل، شارك، وكن جزءًا من مجتمعك الجامعي'
                                : 'Learn, connect, share and be part of your university community',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 55),

                          // ==================================================
                          // START JOURNEY BUTTON
                          // ==================================================

                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AuthChoiceScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: primaryColor,
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                isArabic
                                    ? '🚀 ابدأ رحلتك'
                                    : '🚀 Start Your Journey',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          Text(
                            isArabic
                                ? 'أهلًا بك في زميل'
                                : 'Welcome to Zameel',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AUTH CHOICE SCREEN
// ============================================================

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context);

    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection:
          isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        extendBodyBehindAppBar: true,
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
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    // ==================================================
                    // TITLE
                    // ==================================================

                    const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 70,
                    ),

                    const SizedBox(height: 25),

                    Text(
                      isArabic
                          ? 'مرحبًا بك في زميل'
                          : 'Welcome to Zameel',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      isArabic
                          ? 'اختر كيف تريد المتابعة'
                          : 'Choose how you want to continue',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 45),

                    // ==================================================
                    // LOGIN
                    // ==================================================

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryColor,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          isArabic
                              ? '🔑 تسجيل الدخول'
                              : '🔑 Login',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // CREATE ACCOUNT
                    // ==================================================

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const RoleSelectionScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                            color: Colors.white,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          isArabic
                              ? '📝 إنشاء حساب جديد'
                              : '📝 Create New Account',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),

                    Text(
                      isArabic
                          ? 'يمكنك تسجيل الدخول إذا كان لديك حساب بالفعل'
                          : 'Login if you already have an account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
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