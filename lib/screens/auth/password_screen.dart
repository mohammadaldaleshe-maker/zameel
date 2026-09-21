import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/language_provider.dart';
import 'contact_verification_screen.dart';
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
            AppTheme.glassFill,
            AppTheme.glassSoft,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppTheme.glassBorder,
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactVerificationScreen(
          userData: {
            ...widget.userData,
            'password': _passwordController.text,
            'fullDisplayName': _buildFullName(),
          },
        ),
      ),
    );
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
                        GoogleFonts.ibmPlexSansArabic(
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
                                : AppTheme.muted
                                    .shade400,
                        foregroundColor:
                            passwordValid &&
                                    passwordsMatch
                                ? primaryColor
                                : AppTheme.muted
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
