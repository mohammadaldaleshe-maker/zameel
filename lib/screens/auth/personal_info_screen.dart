import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/language_provider.dart';
import 'password_screen.dart';

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
// PERSONAL INFO SCREEN
// ============================================================

class PersonalInfoScreen extends StatefulWidget {
  final Map<String, dynamic> fullName;
  final String role;
  final String gender;
  final String? university;
  final String? college;
  final String? department;
  final String? academicYear;
  final String? businessType;

  const PersonalInfoScreen({
    super.key,
    required this.fullName,
    required this.role,
    required this.gender,
    this.university,
    this.college,
    this.department,
    this.academicYear,
    this.businessType,
  });

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isValidEmail(String email) {
    final value = email.trim();

    if (value.isEmpty) return false;

    // يمنع المسافات
    if (value.contains(RegExp(r'\s'))) return false;

    // يمنع الأحرف العربية وغير اللاتينية
        final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
    );

    if (!emailRegex.hasMatch(value)) {
      return false;
    }

    // يجب أن يحتوي على @ واحد فقط
    if (value.split('@').length != 2) return false;

    final parts = value.split('@');
    final localPart = parts[0];
    final domain = parts[1];

    if (localPart.isEmpty || domain.isEmpty) return false;

    // يمنع النقطة في بداية أو نهاية الجزء المحلي
    if (localPart.startsWith('.') || localPart.endsWith('.')) {
      return false;
    }

    // يمنع نقطتين متتاليتين
    if (value.contains('..')) return false;

    // يجب أن يحتوي الدومين على نقطة
    if (!domain.contains('.')) return false;

    // الدومين لا يبدأ أو ينتهي بنقطة
    if (domain.startsWith('.') || domain.endsWith('.')) {
      return false;
    }

    // امتداد الدومين يجب أن يحتوي على حرفين على الأقل
    final extension = domain.split('.').last;
    if (extension.length < 2) return false;

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
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
              colors: [gradientStart, gradientEnd],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  Text(
                    isArabic
                        ? '📋 المعلومات الشخصية'
                        : '📋 Personal Information',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    isArabic
                        ? 'أدخل معلوماتك الشخصية للتواصل'
                        : 'Enter your personal information for contact',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // ==================================================
                          // EMAIL
                          // ==================================================
                          GlassContainer(
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: isArabic
                                    ? '📧 البريد الإلكتروني'
                                    : '📧 Email',
                                hintText: isArabic
                                    ? 'example@gmail.com'
                                    : 'example@gmail.com',
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                ),
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                prefixIcon: const Icon(
                                  Icons.email_rounded,
                                  color: Colors.white70,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor:
                                    Colors.white.withAlpha(25),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ==================================================
                          // PHONE
                          // ==================================================
                          GlassContainer(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: isArabic
                                    ? '📱 رقم الهاتف'
                                    : '📱 Phone Number',
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                prefixIcon: const Icon(
                                  Icons.phone_rounded,
                                  color: Colors.white70,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor:
                                    Colors.white.withAlpha(25),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ==================================================
                          // ADDRESS
                          // ==================================================
                          GlassContainer(
                            child: TextField(
                              controller: _addressController,
                              maxLines: 2,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: isArabic
                                    ? '📍 العنوان (اختياري)'
                                    : '📍 Address (Optional)',
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                prefixIcon: const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white70,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor:
                                    Colors.white.withAlpha(25),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ==================================================
                          // SUMMARY
                          // ==================================================
                          GlassContainer(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isArabic
                                      ? '📌 ملخص المعلومات'
                                      : '📌 Summary',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                _buildInfoRow(
                                  isArabic ? '👤 الدور' : '👤 Role',
                                  _getRoleName(isArabic),
                                ),

                                if (widget.university != null)
                                  _buildInfoRow(
                                    isArabic
                                        ? '🏛️ الجامعة'
                                        : '🏛️ University',
                                    widget.university!,
                                  ),

                                if (widget.college != null)
                                  _buildInfoRow(
                                    isArabic
                                        ? '📚 الكلية'
                                        : '📚 College',
                                    widget.college!,
                                  ),

                                if (widget.department != null)
                                  _buildInfoRow(
                                    isArabic
                                        ? '📖 التخصص'
                                        : '📖 Major',
                                    widget.department!,
                                  ),

                                if (widget.academicYear != null)
                                  _buildInfoRow(
                                    isArabic
                                        ? '📅 السنة الدراسية'
                                        : '📅 Academic Year',
                                    widget.academicYear!,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ==================================================
                  // NEXT BUTTON
                  // ==================================================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final email =
                            _emailController.text.trim();
                        final phone =
                            _phoneController.text.trim();

                        // ------------------------------------------
                        // EMAIL EMPTY
                        // ------------------------------------------
                        if (email.isEmpty) {
                          _showError(
                            isArabic
                                ? '❌ يرجى إدخال البريد الإلكتروني'
                                : '❌ Please enter your email',
                          );
                          return;
                        }

                        // ------------------------------------------
                        // EMAIL INVALID
                        // ------------------------------------------
                        if (!_isValidEmail(email)) {
                          _showError(
                            isArabic
                                ? '❌ البريد الإلكتروني غير صحيح. مثال: example@gmail.com'
                                : '❌ Invalid email address. Example: example@gmail.com',
                          );
                          return;
                        }

                        // ------------------------------------------
                        // PHONE EMPTY
                        // ------------------------------------------
                        if (phone.isEmpty) {
                          _showError(
                            isArabic
                                ? '❌ يرجى إدخال رقم الهاتف'
                                : '❌ Please enter your phone number',
                          );
                          return;
                        }

                        // ------------------------------------------
                        // NEXT
                        // ------------------------------------------
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PasswordScreen(
                              userData: {
                                'fullName': widget.fullName,
                                'role': widget.role,
                                'gender': widget.gender,
                                'email': email.toLowerCase(),
                                'phone': phone,
                                'address':
                                    _addressController.text.trim(),
                                'university':
                                    widget.university,
                                'college':
                                    widget.college,
                                'department':
                                    widget.department,
                                'academicYear':
                                    widget.academicYear,
                                'businessType':
                                    widget.businessType,
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryColor,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        isArabic ? 'التالي →' : 'Next →',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      isArabic ? '↩ العودة' : '↩ Back',
                      style: const TextStyle(
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleName(bool isArabic) {
    switch (widget.role) {
      case 'student':
        return isArabic
            ? 'طالب جامعي'
            : 'University Student';

      case 'faculty':
        return isArabic
            ? 'عضو هيئة تدريس'
            : 'Faculty Member';

      case 'business':
        return isArabic
            ? 'نشاط تجاري'
            : 'Business';

      case 'community':
        return isArabic
            ? 'مستخدم مجتمع محلي'
            : 'Community Member';

      default:
        return widget.role;
    }
  }
}