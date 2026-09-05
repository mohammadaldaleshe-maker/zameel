import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/language_provider.dart';
import '../../main.dart';
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
// UNIVERSITY SELECTION SCREEN
// ============================================================

class UniversitySelectionScreen extends StatefulWidget {
  final Map<String, dynamic> fullName;
  final String role;
  final String? academicYear;

  const UniversitySelectionScreen({
    super.key,
    required this.fullName,
    required this.role,
    this.academicYear,
  });

  @override
  State<UniversitySelectionScreen> createState() =>
      _UniversitySelectionScreenState();
}

class _UniversitySelectionScreenState
    extends State<UniversitySelectionScreen> {
  String? selectedUniversity;
  String? selectedCollege;
  String? selectedDepartment;
  String search = '';

  List<University> get filteredUniversities {
    return universities.where((u) {
      return u.name.contains(search) || u.city.contains(search);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final filtered = filteredUniversities;
    final government = filtered.where((u) => u.type == 'حكومية').toList();
    final private = filtered.where((u) => u.type == 'خاصة').toList();

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
                    isArabic ? '🏛️ اختر جامعتك' : '🏛️ Choose Your University',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic
                        ? 'اختر جامعتك وكليتك وتخصصك'
                        : 'Select your university, college and major',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ==============================================
                  // SEARCH BAR
                  // ==============================================
                  GlassContainer(
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          search = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: isArabic ? '🔍 ابحث عن الجامعة...' : '🔍 Search for university...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withAlpha(25),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ==============================================
                  // UNIVERSITY LIST
                  // ==============================================
                  Expanded(
                    child: ListView(
                      children: [
                        if (government.isNotEmpty) ...[
                          Text(
                            isArabic ? '🏛️ جامعات حكومية' : '🏛️ Government Universities',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...government.map((u) => _UniversityCard(
                            university: u,
                            isSelected: selectedUniversity == u.name,
                            onTap: () {
                              setState(() {
                                selectedUniversity = u.name;
                                selectedCollege = null;
                                selectedDepartment = null;
                              });
                            },
                          )),
                          const SizedBox(height: 16),
                        ],
                        if (private.isNotEmpty) ...[
                          Text(
                            isArabic ? '🏛️ جامعات خاصة' : '🏛️ Private Universities',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...private.map((u) => _UniversityCard(
                            university: u,
                            isSelected: selectedUniversity == u.name,
                            onTap: () {
                              setState(() {
                                selectedUniversity = u.name;
                                selectedCollege = null;
                                selectedDepartment = null;
                              });
                            },
                          )),
                        ],
                      ],
                    ),
                  ),
                  // ==============================================
                  // NEXT BUTTON
                  // ==============================================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedUniversity == null
                          ? null
                          : () {
                              final university = universities.firstWhere(
                                  (u) => u.name == selectedUniversity);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CollegeSelectionScreen(
                                    fullName: widget.fullName,
                                    role: widget.role,
                                    academicYear: widget.academicYear,
                                    university: university,
                                  ),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedUniversity != null
                            ? Colors.white
                            : Colors.grey.shade400,
                        foregroundColor: selectedUniversity != null
                            ? primaryColor
                            : Colors.grey.shade600,
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

// ============================================================
// UNIVERSITY CARD
// ============================================================

class _UniversityCard extends StatelessWidget {
  final University university;
  final bool isSelected;
  final VoidCallback onTap;

  const _UniversityCard({
    required this.university,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_rounded,
                color: isSelected ? Colors.white : Colors.white70,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translateText(university.name, languageProvider.currentLanguage),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    isArabic
                        ? '📍 ${university.city} - ${university.type}'
                        : '📍 ${university.city} - ${university.type}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// COLLEGE SELECTION SCREEN
// ============================================================

class CollegeSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> fullName;
  final String role;
  final String? academicYear;
  final University university;

  const CollegeSelectionScreen({
    super.key,
    required this.fullName,
    required this.role,
    required this.academicYear,
    required this.university,
  });

  @override
  State<CollegeSelectionScreen> createState() =>
      _CollegeSelectionScreenState();
}

class _CollegeSelectionScreenState extends State<CollegeSelectionScreen> {
  String? selectedCollege;

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
                  Text(
                    isArabic ? '📚 اختر الكلية' : '📚 Choose College',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    translateText(widget.university.name, languageProvider.currentLanguage),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: widget.university.colleges.map((college) {
                        final isSelected = selectedCollege == college.name;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedCollege = college.name;
                            });
                          },
                          child: GlassContainer(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.school_rounded,
                                    color: isSelected ? Colors.white : Colors.white70,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    translateText(college.name,
                                        languageProvider.currentLanguage),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedCollege == null
                          ? null
                          : () {
                              final college = widget.university.colleges
                                  .firstWhere((c) => c.name == selectedCollege);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DepartmentSelectionScreen(
                                    fullName: widget.fullName,
                                    role: widget.role,
                                    academicYear: widget.academicYear,
                                    university: widget.university,
                                    college: college,
                                  ),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedCollege != null
                            ? Colors.white
                            : Colors.grey.shade400,
                        foregroundColor: selectedCollege != null
                            ? primaryColor
                            : Colors.grey.shade600,
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

// ============================================================
// DEPARTMENT SELECTION SCREEN
// ============================================================

class DepartmentSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> fullName;
  final String role;
  final String? academicYear;
  final University university;
  final College college;

  const DepartmentSelectionScreen({
    super.key,
    required this.fullName,
    required this.role,
    required this.academicYear,
    required this.university,
    required this.college,
  });

  @override
  State<DepartmentSelectionScreen> createState() =>
      _DepartmentSelectionScreenState();
}

class _DepartmentSelectionScreenState
    extends State<DepartmentSelectionScreen> {
  String? selectedDepartment;

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
                  Text(
                    isArabic ? '📖 اختر التخصص' : '📖 Choose Major',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    translateText(widget.college.name, languageProvider.currentLanguage),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: widget.college.departments.map((dept) {
                        final isSelected = selectedDepartment == dept;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDepartment = dept;
                            });
                          },
                          child: GlassContainer(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    color: isSelected ? Colors.white : Colors.white70,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    translateText(dept,
                                        languageProvider.currentLanguage),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedDepartment == null
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PersonalInfoScreen(
                                    fullName: widget.fullName,
                                    role: widget.role,
                                    gender: 'male', // سيتم استلامه من الشاشة السابقة
                                    university: widget.university.name,
                                    college: widget.college.name,
                                    department: selectedDepartment!,
                                    academicYear: widget.academicYear,
                                  ),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedDepartment != null
                            ? Colors.white
                            : Colors.grey.shade400,
                        foregroundColor: selectedDepartment != null
                            ? primaryColor
                            : Colors.grey.shade600,
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