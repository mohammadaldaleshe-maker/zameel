import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/language_provider.dart';
import 'academic_year_screen.dart';
import 'personal_info_screen.dart';

const Color primaryColor = Color(0xFF6C63FF);
const Color gradientStart = Color(0xFF6C63FF);
const Color gradientEnd = Color(0xFF4A3B8A);

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

class NameEntryScreen extends StatefulWidget {
  final String role;

  const NameEntryScreen({
    super.key,
    required this.role,
  });

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final TextEditingController _firstNameController =
      TextEditingController();

  final TextEditingController _fatherNameController =
      TextEditingController();

  final TextEditingController _grandfatherNameController =
      TextEditingController();

  final TextEditingController _familyNameController =
      TextEditingController();

  String? selectedGender;

  @override
  void dispose() {
    _firstNameController.dispose();
    _fatherNameController.dispose();
    _grandfatherNameController.dispose();
    _familyNameController.dispose();
    super.dispose();
  }

  void _goNext(bool isArabic) {
    final firstName = _firstNameController.text.trim();
    final fatherName = _fatherNameController.text.trim();
    final grandfatherName = _grandfatherNameController.text.trim();
    final familyName = _familyNameController.text.trim();

    if (firstName.isEmpty || fatherName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'الرجاء إدخال الاسم الأول واسم الأب'
                : "Please enter first name and father's name",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'الرجاء اختيار الجنس'
                : 'Please select gender',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final fullName = <String, String?>{
      'firstName': firstName,
      'fatherName': fatherName,
      'grandfatherName': grandfatherName,
      'familyName': familyName,
      'gender': selectedGender,
    };

    Widget nextScreen;

    switch (widget.role) {
      case 'student':
        nextScreen = AcademicYearScreen(
          fullName: fullName,
          role: widget.role,
        );
        break;

      default:
        nextScreen = PersonalInfoScreen(
          fullName: fullName,
          role: widget.role,
          gender: selectedGender!,
        );
        break;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => nextScreen,
      ),
    );
  }

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  Text(
                    isArabic
                        ? '👤 الاسم الكامل'
                        : '👤 Full Name',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    isArabic
                        ? 'أدخل اسمك كما يظهر في الهوية الرسمية'
                        : 'Enter your name as it appears on official ID',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 30),

                  _NameField(
                    controller: _firstNameController,
                    label:
                        isArabic ? 'الاسم الأول' : 'First Name',
                    icon: Icons.person_rounded,
                  ),

                  const SizedBox(height: 16),

                  _NameField(
                    controller: _fatherNameController,
                    label:
                        isArabic ? 'اسم الأب' : "Father's Name",
                    icon: Icons.person_rounded,
                  ),

                  const SizedBox(height: 16),

                  _NameField(
                    controller: _grandfatherNameController,
                    label:
                        isArabic
                            ? 'اسم الجد'
                            : "Grandfather's Name",
                    icon: Icons.person_rounded,
                  ),

                  const SizedBox(height: 16),

                  _NameField(
                    controller: _familyNameController,
                    label:
                        isArabic ? 'اسم العائلة' : 'Family Name',
                    icon: Icons.family_restroom_rounded,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    isArabic ? 'الجنس' : 'Gender',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _GenderButton(
                          label:
                              isArabic ? 'ذكر' : 'Male',
                          isSelected:
                              selectedGender == 'male',
                          onTap: () {
                            setState(() {
                              selectedGender = 'male';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GenderButton(
                          label:
                              isArabic ? 'أنثى' : 'Female',
                          isSelected:
                              selectedGender == 'female',
                          onTap: () {
                            setState(() {
                              selectedGender = 'female';
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _goNext(isArabic),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryColor,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        isArabic
                            ? 'التالي →'
                            : 'Next →',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        isArabic
                            ? '↩ العودة'
                            : '↩ Back',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _NameField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.white70,
          ),
          prefixIcon: Icon(
            icon,
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
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withAlpha(25)
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Colors.white70,
              fontWeight: isSelected
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}