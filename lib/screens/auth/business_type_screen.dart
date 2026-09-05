import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/language_provider.dart';
import 'personal_info_screen.dart';

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
// BUSINESS TYPE SCREEN
// ============================================================

class BusinessTypeScreen extends StatefulWidget {
  final Map<String, dynamic> fullName;
  final String role;
  final String gender;

  const BusinessTypeScreen({
    super.key,
    required this.fullName,
    required this.role,
    required this.gender,
  });

  @override
  State<BusinessTypeScreen> createState() => _BusinessTypeScreenState();
}

class _BusinessTypeScreenState extends State<BusinessTypeScreen> {
  String? selectedType;
  final TextEditingController _customTypeController = TextEditingController();
  bool _isCustom = false;

  final List<Map<String, String>> businessTypes = [
    {'id': 'cafe', 'ar': '☕ مقهى', 'en': '☕ Cafe'},
    {'id': 'restaurant', 'ar': '🍽️ مطعم', 'en': '🍽️ Restaurant'},
    {'id': 'bookstore', 'ar': '📚 مكتبة', 'en': '📚 Bookstore'},
    {'id': 'electronics', 'ar': '💻 إلكترونيات', 'en': '💻 Electronics'},
    {'id': 'clothing', 'ar': '👕 ملابس', 'en': '👕 Clothing'},
    {'id': 'gym', 'ar': '🏋️ نادي رياضي', 'en': '🏋️ Gym'},
    {'id': 'coffee_shop', 'ar': '☕ محل قهوة', 'en': '☕ Coffee Shop'},
    {'id': 'stationery', 'ar': '📝 قرطاسية', 'en': '📝 Stationery'},
    {'id': 'pharmacy', 'ar': '💊 صيدلية', 'en': '💊 Pharmacy'},
    {'id': 'supermarket', 'ar': '🛒 سوبرماركت', 'en': '🛒 Supermarket'},
    {'id': 'service', 'ar': '🔧 خدمات', 'en': '🔧 Services'},
    {'id': 'other', 'ar': '📌 أخرى', 'en': '📌 Other'},
  ];

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
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
                  // ==============================================
                  // HEADER
                  // ==============================================
                  Text(
                    isArabic ? '🏢 نوع النشاط التجاري' : '🏢 Business Type',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic
                        ? 'اختر نوع النشاط التجاري الذي تمثله'
                        : 'Select the type of business you represent',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ==============================================
                  // BUSINESS TYPES GRID
                  // ==============================================
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: businessTypes.length,
                      itemBuilder: (context, index) {
                        final type = businessTypes[index];
                        final isSelected = selectedType == type['id'];
                        final label = isArabic ? type['ar'] : type['en'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedType = type['id'];
                              _isCustom = type['id'] == 'other';
                              if (!_isCustom) {
                                _customTypeController.clear();
                              }
                            });
                          },
                          child: GlassContainer(
                            padding: const EdgeInsets.all(8),
                            borderRadius: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    label ?? '',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(height: 4),
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // ==============================================
                  // CUSTOM TYPE INPUT
                  // ==============================================
                  if (_isCustom) ...[
                    const SizedBox(height: 12),
                    GlassContainer(
                      child: TextField(
                        controller: _customTypeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: isArabic ? '✏️ اكتب نوع النشاط' : '✏️ Enter business type',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.edit_rounded,
                              color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withAlpha(25),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // ==============================================
                  // NEXT BUTTON
                  // ==============================================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        String type = selectedType ?? '';
                        if (_isCustom) {
                          if (_customTypeController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isArabic
                                      ? '❌ الرجاء كتابة نوع النشاط'
                                      : '❌ Please enter business type',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          type = _customTypeController.text.trim();
                        }

                        if (type.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isArabic
                                    ? '❌ الرجاء اختيار نوع النشاط'
                                    : '❌ Please select business type',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PersonalInfoScreen(
                              fullName: widget.fullName,
                              role: widget.role,
                              gender: widget.gender,
                              businessType: type,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
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
}