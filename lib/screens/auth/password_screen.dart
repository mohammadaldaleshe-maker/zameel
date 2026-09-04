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

const Color primaryColor = Color(0xFF6C63FF);
const Color gradientStart = Color(0xFF6C63FF);
const Color gradientEnd = Color(0xFF4A3B8A);

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
// PASSWORD SCREEN
// ============================================================

class PasswordScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PasswordScreen({
    super.key,
    required this.userData,
  });

  @override
  State<PasswordScreen> createState() =>
      _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;

  String? _passwordError;

  // ============================================================
  // PASSWORD VALIDATION
  // ============================================================

  bool get _isPasswordValid {
    final password = _passwordController.text;

    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;

    return true;
  }

  bool get _doPasswordsMatch {
    return _passwordController.text ==
            _confirmPasswordController.text &&
        _confirmPasswordController.text.isNotEmpty;
  }

  // ============================================================
  // VALIDATE PASSWORD
  // ============================================================

  void _validatePassword() {
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _passwordError = null;
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        _passwordError =
            'يجب أن تكون كلمة المرور 8 أحرف على الأقل';
      });
      return;
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      setState(() {
        _passwordError =
            'يجب أن تحتوي على حرف كبير (A-Z)';
      });
      return;
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      setState(() {
        _passwordError =
            'يجب أن تحتوي على حرف صغير (a-z)';
      });
      return;
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      setState(() {
        _passwordError =
            'يجب أن تحتوي على رقم (0-9)';
      });
      return;
    }

    setState(() {
      _passwordError = null;
    });
  }

  // ============================================================
  // BUILD FULL NAME
  // ============================================================

  String _buildFullName() {
    final rawFullName = widget.userData['fullName'];

    if (rawFullName is! Map) {
      return 'مستخدم';
    }

    final fullName =
        Map<String, dynamic>.from(rawFullName);

    final parts = [
      (fullName['firstName'] ?? '')
          .toString()
          .trim(),
      (fullName['fatherName'] ?? '')
          .toString()
          .trim(),
      (fullName['grandfatherName'] ?? '')
          .toString()
          .trim(),
      (fullName['familyName'] ?? '')
          .toString()
          .trim(),
    ].where((part) => part.isNotEmpty).toList();

    return parts.isEmpty
        ? 'مستخدم'
        : parts.join(' ');
  }

  // ============================================================
  // CREATE ACCOUNT
  // ============================================================

  Future<void> _createAccount() async {
    if (_isLoading) return;

    if (!_isPasswordValid) {
      _validatePassword();
      return;
    }

    if (!_doPasswordsMatch) {
      return;
    }

    final email =
        (widget.userData['email'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (email.isEmpty) {
      _showMessage(
        'البريد الإلكتروني غير موجود.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase =
          Supabase.instance.client;

      final password =
          _passwordController.text;

      // ========================================================
      // CREATE SUPABASE AUTH ACCOUNT ONCE
      // ========================================================

      final response =
          await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': _buildFullName(),
          'role':
              (widget.userData['role'] ?? '')
                  .toString(),
        },
      );

      final user = response.user;

      if (user == null) {
        throw const AuthException(
          'تعذر إنشاء حساب المستخدم.',
        );
      }

      // ========================================================
      // DEVELOPMENT MODE
      //
      // Confirm email = OFF
      // We expect a session immediately.
      // ========================================================

      if (response.session == null) {
        throw const AuthException(
          'تم إنشاء الحساب، لكن الجلسة لم تُنشأ. '
          'تأكد من أن Confirm email معطل في Supabase.',
        );
      }

      // ========================================================
      // PREPARE USERS DATA
      // ========================================================

      final fullName = _buildFullName();

      await supabase.from('users').upsert(
        {
          'id': user.id,
          'email': user.email ?? email,
          'name': fullName,
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

      if (!mounted) return;

      // ========================================================
      // SUCCESS
      // ========================================================

      _showMessage(
        'تم إنشاء حسابك بنجاح',
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
          builder: (_) =>
              ProfilePictureScreen(
            userData: {
              ...widget.userData,
              'email': email,
              'supabase_user_id':
                  user.id,
              'email_verified': false,
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
        'حدث خطأ أثناء إنشاء الحساب.',
      );

      debugPrint(
        'Create account error: $e',
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
          backgroundColor:
              success
                  ? Colors.green.shade700
                  : Colors.red.shade700,
          behavior:
              SnackBarBehavior.floating,
          duration:
              const Duration(seconds: 3),
        ),
      );
  }

  // ============================================================
  // AUTH ERROR TRANSLATION
  // ============================================================

  String _translateAuthError(
    String message,
  ) {
    final lower =
        message.toLowerCase();

    if (lower.contains(
          'already registered',
        ) ||
        lower.contains(
          'already exists',
        ) ||
        lower.contains(
          'user already',
        )) {
      return 'هذا البريد الإلكتروني مستخدم بالفعل.';
    }

    if (lower.contains(
      'invalid email',
    )) {
      return 'البريد الإلكتروني غير صالح.';
    }

    if (lower.contains(
      'password',
    ) &&
        lower.contains(
          'weak',
        )) {
      return 'كلمة المرور ضعيفة.';
    }

    if (lower.contains(
      'rate limit',
    )) {
      return 'تم تجاوز عدد المحاولات. حاول لاحقًا.';
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(
      context,
    );

    final isArabic =
        languageProvider.isArabic;

    final passwordValid =
        _isPasswordValid;

    final passwordsMatch =
        _doPasswordsMatch;

    return Directionality(
      textDirection:
          isArabic
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
      child: Scaffold(
        body: Container(
          decoration:
              const BoxDecoration(
            gradient:
                LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                gradientStart,
                gradientEnd,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 10,
                  ),

                  // ==================================================
                  // HEADER
                  // ==================================================

                  Text(
                    isArabic
                        ? '🔐 كلمة المرور'
                        : '🔐 Password',
                    style:
                        GoogleFonts.cairo(
                      color:
                          Colors.white,
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    isArabic
                        ? 'أنشئ كلمة مرور قوية لحماية حسابك'
                        : 'Create a strong password to protect your account',
                    style:
                        const TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ==================================================
                  // PASSWORD REQUIREMENTS
                  // ==================================================

                  GlassContainer(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          isArabic
                              ? '📌 متطلبات كلمة المرور:'
                              : '📌 Password Requirements:',
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight
                                    .bold,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        _buildRequirement(
                          isArabic
                              ? '8 أحرف على الأقل'
                              : 'At least 8 characters',
                          _passwordController
                                  .text
                                  .length >=
                              8,
                        ),

                        _buildRequirement(
                          isArabic
                              ? 'حرف كبير (A-Z)'
                              : 'Uppercase letter (A-Z)',
                          _passwordController
                              .text
                              .contains(
                            RegExp(
                              r'[A-Z]',
                            ),
                          ),
                        ),

                        _buildRequirement(
                          isArabic
                              ? 'حرف صغير (a-z)'
                              : 'Lowercase letter (a-z)',
                          _passwordController
                              .text
                              .contains(
                            RegExp(
                              r'[a-z]',
                            ),
                          ),
                        ),

                        _buildRequirement(
                          isArabic
                              ? 'رقم (0-9)'
                              : 'Number (0-9)',
                          _passwordController
                              .text
                              .contains(
                            RegExp(
                              r'[0-9]',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // PASSWORD FIELD
                  // ==================================================

                  GlassContainer(
                    child:
                        TextField(
                      controller:
                          _passwordController,
                      obscureText:
                          _obscurePassword,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                      ),
                      onChanged:
                          (_) {
                        _validatePassword();
                        setState(
                          () {},
                        );
                      },
                      decoration:
                          InputDecoration(
                        labelText:
                            isArabic
                                ? '🔑 كلمة المرور'
                                : '🔑 Password',
                        labelStyle:
                            const TextStyle(
                          color:
                              Colors.white70,
                        ),
                        prefixIcon:
                            const Icon(
                          Icons
                              .lock_rounded,
                          color:
                              Colors.white70,
                        ),
                        suffixIcon:
                            IconButton(
                          onPressed: () {
                            setState(
                              () {
                                _obscurePassword =
                                    !_obscurePassword;
                              },
                            );
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons
                                    .visibility_rounded
                                : Icons
                                    .visibility_off_rounded,
                            color:
                                Colors.white70,
                          ),
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            16,
                          ),
                          borderSide:
                              BorderSide
                                  .none,
                        ),
                        filled:
                            true,
                        fillColor:
                            Colors.white
                                .withAlpha(
                          25,
                        ),
                        errorText:
                            _passwordError,
                        errorStyle:
                            const TextStyle(
                          color:
                              Colors.redAccent,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // CONFIRM PASSWORD
                  // ==================================================

                  GlassContainer(
                    child:
                        TextField(
                      controller:
                          _confirmPasswordController,
                      obscureText:
                          _obscureConfirmPassword,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                      ),
                      onChanged:
                          (_) {
                        setState(
                          () {},
                        );
                      },
                      decoration:
                          InputDecoration(
                        labelText:
                            isArabic
                                ? '✅ تأكيد كلمة المرور'
                                : '✅ Confirm Password',
                        labelStyle:
                            const TextStyle(
                          color:
                              Colors.white70,
                        ),
                        prefixIcon:
                            const Icon(
                          Icons
                              .lock_outline_rounded,
                          color:
                              Colors.white70,
                        ),
                        suffixIcon:
                            IconButton(
                          onPressed: () {
                            setState(
                              () {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              },
                            );
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons
                                    .visibility_rounded
                                : Icons
                                    .visibility_off_rounded,
                            color:
                                Colors.white70,
                          ),
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            16,
                          ),
                          borderSide:
                              BorderSide
                                  .none,
                        ),
                        filled:
                            true,
                        fillColor:
                            Colors.white
                                .withAlpha(
                          25,
                        ),
                        errorText:
                            passwordsMatch ||
                                    _confirmPasswordController
                                        .text
                                        .isEmpty
                                ? null
                                : isArabic
                                    ? '❌ كلمة المرور غير متطابقة'
                                    : '❌ Passwords do not match',
                        errorStyle:
                            const TextStyle(
                          color:
                              Colors.redAccent,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ==================================================
                  // CREATE ACCOUNT BUTTON
                  // ==================================================

                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        ElevatedButton(
                      onPressed:
                          (_isLoading ||
                                  !passwordValid ||
                                  !passwordsMatch)
                              ? null
                              : _createAccount,
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            passwordValid &&
                                    passwordsMatch
                                ? Colors.white
                                : Colors.grey
                                    .shade400,
                        foregroundColor:
                            passwordValid &&
                                    passwordsMatch
                                ? primaryColor
                                : Colors.grey
                                    .shade600,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 16,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            30,
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child:
                                  CircularProgressIndicator(
                                color:
                                    primaryColor,
                                strokeWidth:
                                    2,
                              ),
                            )
                          : Text(
                              isArabic
                                  ? 'إنشاء الحساب →'
                                  : 'Create Account →',
                              style:
                                  const TextStyle(
                                fontSize:
                                    18,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  // ==================================================
                  // BACK
                  // ==================================================

                  TextButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                );
                              },
                    child: Text(
                      isArabic
                          ? '↩ العودة'
                          : '↩ Back',
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize:
                            14,
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

  // ============================================================
  // PASSWORD REQUIREMENT WIDGET
  // ============================================================

  Widget _buildRequirement(
    String text,
    bool isMet,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 2,
      ),
      child: Row(
        children: [
          Icon(
            isMet
                ? Icons.check_circle_rounded
                : Icons.circle_rounded,
            color: isMet
                ? Colors.green
                : Colors.white24,
            size: 16,
          ),
          const SizedBox(
            width: 8,
          ),
          Text(
            text,
            style:
                TextStyle(
              color: isMet
                  ? Colors.white
                  : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
