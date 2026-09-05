import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';
import '../../main.dart';

// ============================================================
// VERIFICATION SCREEN
// ============================================================

class VerificationScreen extends StatefulWidget {
  final String email;
  final String role;
  final String verificationCode;

  const VerificationScreen({
    super.key,
    required this.email,
    required this.role,
    required this.verificationCode,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _timer = 60;
  bool _isResendEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = 60;
    _isResendEnabled = false;
    Future.delayed(const Duration(seconds: 1), _updateTimer);
  }

  void _updateTimer() {
    if (_timer > 0) {
      setState(() {
        _timer--;
      });
      Future.delayed(const Duration(seconds: 1), _updateTimer);
    } else {
      setState(() {
        _isResendEnabled = true;
      });
    }
  }

  String _getEnteredCode() {
    return _codeControllers.map((c) => c.text).join();
  }

  void _verifyCode() {
    final code = _getEnteredCode();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).isArabic
                ? '⚠️ يرجى إدخال رمز التحقق كاملاً (6 أرقام)'
                : '⚠️ Please enter the full verification code (6 digits)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (code != widget.verificationCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ رمز التحقق غير صحيح. حاول مرة أخرى.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // محاكاة عملية التحقق
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
      });

      // ✅ تسجيل الدخول ناجح
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => UniversityScreen(),
        ),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).isArabic
                ? '✅ تم التحقق بنجاح! مرحباً بك في Zameel'
                : '✅ Verification successful! Welcome to Zameel',
          ),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _resendCode() {
    // محاكاة إعادة إرسال الرمز
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Provider.of<LanguageProvider>(context, listen: false).isArabic
              ? '📨 تم إرسال رمز تحقق جديد إلى بريدك الإلكتروني'
              : '📨 A new verification code has been sent to your email',
        ),
        backgroundColor: Color(0xFF18D3C3),
      ),
    );
    _startTimer();
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FAF9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0B9F95)),
          ),
          title: Text(
            isArabic ? '🔐 رمز التحقق' : '🔐 Verification Code',
            style: const TextStyle(
              color: Color(0xFF0B9F95),
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ==============================================
                    // ICON
                    // ==============================================
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18D3C3).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_rounded,
                        color: Color(0xFF18D3C3),
                        size: 40,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==============================================
                    // TITLE
                    // ==============================================
                    Text(
                      isArabic ? 'تحقق من بريدك الإلكتروني' : 'Check Your Email',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B9F95),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ==============================================
                    // SUBTITLE
                    // ==============================================
                    Text(
                      isArabic
                          ? 'لقد أرسلنا رمز تحقق مكون من 6 أرقام إلى:'
                          : 'We have sent a 6-digit verification code to:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.email,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18D3C3),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ==============================================
                    // CODE INPUT FIELDS
                    // ==============================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        return Container(
                          width: 44,
                          height: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextField(
                            controller: _codeControllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF18D3C3),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(4),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty && index < 5) {
                                _focusNodes[index + 1].requestFocus();
                              }
                              if (value.isEmpty && index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                            },
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 8),

                    // ==============================================
                    // VERIFICATION CODE HINT
                    // ==============================================
                    Text(
                      isArabic
                          ? '📝 الرمز: ${widget.verificationCode} (للاختبار)'
                          : '📝 Code: ${widget.verificationCode} (for testing)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==============================================
                    // VERIFY BUTTON
                    // ==============================================
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF18D3C3),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isArabic
                                    ? '🔓 التحقق من الرمز'
                                    : '🔓 Verify Code',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==============================================
                    // RESEND
                    // ==============================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isArabic
                              ? 'لم يصلك الرمز؟ '
                              : 'Didn\'t receive code? ',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        if (_isResendEnabled)
                          GestureDetector(
                            onTap: _resendCode,
                            child: const Text(
                              'إعادة الإرسال',
                              style: TextStyle(
                                color: Color(0xFF18D3C3),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          Text(
                            '$_timer ثانية',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ==============================================
                    // BACK BUTTON
                    // ==============================================
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          isArabic
                              ? '⬅️ العودة لتسجيل الدخول'
                              : '⬅️ Back to login',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
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