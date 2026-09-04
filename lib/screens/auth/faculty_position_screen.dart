import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../providers/language_provider.dart';
import '../../main.dart';
import 'welcome_screen.dart'; // ✅ أضف هذا السطر
import 'university_selection_screen.dart';

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
// FACULTY POSITION SCREEN
// ============================================================

class FacultyPositionScreen extends StatefulWidget {
  final Map<String, dynamic> fullName;
  final String role;
  final String gender;

  const FacultyPositionScreen({
    super.key,
    required this.fullName,
    required this.role,
    required this.gender,
  });

  @override
  State<FacultyPositionScreen> createState() =>
      _FacultyPositionScreenState();
}

class _FacultyPositionScreenState extends State<FacultyPositionScreen> {
  String? selectedPosition;
  final TextEditingController _customPositionController =
      TextEditingController();
  bool _isCustom = false;

  final List<Map<String, String>> positions = [
    {'id': 'professor', 'ar': 'أستاذ', 'en': 'Professor'},
    {'id': 'associate_professor', 'ar': 'أستاذ مشارك', 'en': 'Associate Professor'},
    {'id': 'assistant_professor', 'ar': 'أستاذ مساعد', 'en': 'Assistant Professor'},
    {'id': 'lecturer', 'ar': 'محاضر', 'en': 'Lecturer'},
    {'id': 'head_of_department', 'ar': 'رئيس قسم', 'en': 'Head of Department'},
    {'id': 'dean', 'ar': 'عميد كلية', 'en': 'Dean'},
    {'id': 'assistant_dean', 'ar': 'مساعد العميد', 'en': 'Assistant Dean'},
    {'id': 'vice_president', 'ar': 'نائب الرئيس', 'en': 'Vice President'},
    {'id': 'president', 'ar': 'رئيس الجامعة', 'en': 'President'},
    {'id': 'other', 'ar': 'أخرى', 'en': 'Other'},
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
                    isArabic ? '👨‍🏫 المسمى الوظيفي' : '👨‍🏫 Job Title',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic
                        ? 'اختر مسمى وظيفتك في الجامعة'
                        : 'Select your job title at the university',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ==============================================
                  // POSITIONS GRID
                  // ==============================================
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: positions.length,
                      itemBuilder: (context, index) {
                        final position = positions[index];
                        final isSelected = selectedPosition == position['id'];
                        final label = isArabic ? position['ar'] : position['en'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedPosition = position['id'];
                              _isCustom = position['id'] == 'other';
                              if (!_isCustom) {
                                _customPositionController.clear();
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
                                  Icon(
                                    Icons.work_rounded,
                                    color: isSelected ? Colors.white : Colors.white70,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    label ?? '',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 13,
                                      height: 1.2,
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
                  // CUSTOM POSITION INPUT
                  // ==============================================
                  if (_isCustom) ...[
                    const SizedBox(height: 12),
                    GlassContainer(
                      child: TextField(
                        controller: _customPositionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: isArabic ? '✏️ اكتب المسمى الوظيفي' : '✏️ Enter job title',
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
                        String position = selectedPosition ?? '';
                        if (_isCustom) {
                          if (_customPositionController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isArabic
                                      ? '❌ الرجاء كتابة المسمى الوظيفي'
                                      : '❌ Please enter your job title',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          position = _customPositionController.text.trim();
                        }

                        if (position.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isArabic
                                    ? '❌ الرجاء اختيار المسمى الوظيفي'
                                    : '❌ Please select your job title',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UniversitySelectionScreen(
                              fullName: widget.fullName,
                              role: widget.role,
                              academicYear: null,
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