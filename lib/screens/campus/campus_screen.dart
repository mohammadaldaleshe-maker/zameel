import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';
import 'live_map_screen.dart';

// ============================================================
// ZAMEEL CAMPUS SCREEN
// ============================================================

class CampusScreen extends StatefulWidget {
  const CampusScreen({super.key});

  @override
  State<CampusScreen> createState() => _CampusScreenState();
}

class _CampusScreenState extends State<CampusScreen> {
  int selectedTab = 0; // 0 = الخريطة, 1 = المباني, 2 = الخدمات

  final List<Map<String, dynamic>> buildings = [
    {
      'id': 1,
      'name_ar': 'كلية تكنولوجيا المعلومات',
      'name_en': 'Faculty of Information Technology',
      'type_ar': 'كلية',
      'type_en': 'Faculty',
      'description_ar': 'مبنى كلية تكنولوجيا المعلومات - الطابق الثالث',
      'description_en': 'Faculty of IT Building - 3rd Floor',
      'location': 'A1',
      'color': 0xFF18D4C6,
      'icon': Icons.computer_rounded,
      'students': 1200,
      'floors': 4,
    },
    {
      'id': 2,
      'name_ar': 'كلية الهندسة',
      'name_en': 'Faculty of Engineering',
      'type_ar': 'كلية',
      'type_en': 'Faculty',
      'description_ar': 'مبنى كلية الهندسة - الطابق الثاني',
      'description_en': 'Faculty of Engineering Building - 2nd Floor',
      'location': 'B2',
      'color': 0xFF18D4C6,
      'icon': Icons.engineering_rounded,
      'students': 1500,
      'floors': 5,
    },
    {
      'id': 3,
      'name_ar': 'كلية الأعمال',
      'name_en': 'Faculty of Business',
      'type_ar': 'كلية',
      'type_en': 'Faculty',
      'description_ar': 'مبنى كلية الأعمال - الطابق الأول',
      'description_en': 'Faculty of Business Building - 1st Floor',
      'location': 'C3',
      'color': 0xFF18D4C6,
      'icon': Icons.business_center_rounded,
      'students': 900,
      'floors': 3,
    },
    {
      'id': 4,
      'name_ar': 'المكتبة المركزية',
      'name_en': 'Central Library',
      'type_ar': 'مكتبة',
      'type_en': 'Library',
      'description_ar': 'المكتبة المركزية - مفتوحة 24 ساعة',
      'description_en': 'Central Library - Open 24/7',
      'location': 'D4',
      'color': 0xFF079E93,
      'icon': Icons.local_library_rounded,
      'students': 0,
      'floors': 3,
    },
    {
      'id': 5,
      'name_ar': 'قاعة المؤتمرات',
      'name_en': 'Conference Hall',
      'type_ar': 'قاعة',
      'type_en': 'Hall',
      'description_ar': 'قاعة المؤتمرات الكبرى - تتسع لـ 500 شخص',
      'description_en': 'Main Conference Hall - Seats 500 people',
      'location': 'E5',
      'color': 0xFF18D4C6,
      'icon': Icons.event_rounded,
      'students': 0,
      'floors': 2,
    },
    {
      'id': 6,
      'name_ar': 'مقهى الجامعة',
      'name_en': 'University Cafe',
      'type_ar': 'مقهى',
      'type_en': 'Cafe',
      'description_ar': 'مقهى الجامعة - أفضل قهوة في الحرم',
      'description_en': 'University Cafe - Best coffee on campus',
      'location': 'F6',
      'color': 0xFF079E93,
      'icon': Icons.local_cafe_rounded,
      'students': 0,
      'floors': 1,
    },
    {
      'id': 7,
      'name_ar': 'كلية العلوم',
      'name_en': 'Faculty of Science',
      'type_ar': 'كلية',
      'type_en': 'Faculty',
      'description_ar': 'مبنى كلية العلوم - مختبرات متطورة',
      'description_en': 'Faculty of Science Building - Advanced Labs',
      'location': 'G7',
      'color': 0xFF18D4C6,
      'icon': Icons.science_rounded,
      'students': 1100,
      'floors': 4,
    },
    {
      'id': 8,
      'name_ar': 'مبنى الإدارة',
      'name_en': 'Administration Building',
      'type_ar': 'إدارة',
      'type_en': 'Administration',
      'description_ar': 'مبنى إدارة الجامعة - الطابق الخامس',
      'description_en': 'University Administration Building - 5th Floor',
      'location': 'H8',
      'color': 0xFF079E93,
      'icon': Icons.admin_panel_settings_rounded,
      'students': 0,
      'floors': 5,
    },
  ];

  final List<Map<String, dynamic>> services = [
    {
      'id': 1,
      'name_ar': 'مطعم الطلاب',
      'name_en': 'Student Restaurant',
      'type_ar': 'مطعم',
      'type_en': 'Restaurant',
      'description_ar': 'مطعم يقدم وجبات طازجة للطلاب',
      'description_en': 'Restaurant serving fresh meals for students',
      'location': 'G7',
      'color': 0xFF18D4C6,
      'icon': Icons.restaurant_rounded,
      'students': 0,
      'floors': 2,
    },
    {
      'id': 2,
      'name_ar': 'مواقف السيارات',
      'name_en': 'Parking',
      'type_ar': 'مواقف',
      'type_en': 'Parking',
      'description_ar': 'مواقف سيارات تتسع لـ 500 سيارة',
      'description_en': 'Parking for 500 cars',
      'location': 'H8',
      'color': 0xFF079E93,
      'icon': Icons.local_parking_rounded,
      'students': 0,
      'floors': 0,
    },
    {
      'id': 3,
      'name_ar': 'عيادة الجامعة',
      'name_en': 'University Clinic',
      'type_ar': 'عيادة',
      'type_en': 'Clinic',
      'description_ar': 'عيادة طبية تقدم خدمات صحية للطلاب',
      'description_en': 'Medical clinic providing health services to students',
      'location': 'I9',
      'color': 0xFFF44336,
      'icon': Icons.local_hospital_rounded,
      'students': 0,
      'floors': 2,
    },
    {
      'id': 4,
      'name_ar': 'صالة الألعاب الرياضية',
      'name_en': 'Gym',
      'type_ar': 'رياضة',
      'type_en': 'Sports',
      'description_ar': 'صالة رياضية مجهزة بالكامل',
      'description_en': 'Fully equipped gym',
      'location': 'J10',
      'color': 0xFF079E93,
      'icon': Icons.fitness_center_rounded,
      'students': 0,
      'floors': 2,
    },
  ];

  final List<Map<String, dynamic>> nearbyCompanies = [
    {
      'id': 1,
      'name': 'Tech Solutions',
      'type_ar': 'شركة تقنية',
      'type_en': 'Tech Company',
      'distance': '500 متر',
      'description_ar': 'شركة تقدم حلول برمجية للطلاب',
      'description_en': 'Company providing software solutions for students',
      'icon': Icons.business_center_rounded,
      'color': 0xFF18D4C6,
    },
    {
      'id': 2,
      'name': 'Code Cafe',
      'type_ar': 'مقهى برمجي',
      'type_en': 'Code Cafe',
      'distance': '300 متر',
      'description_ar': 'مقهى يجمع بين القهوة والبرمجة',
      'description_en': 'Cafe combining coffee and coding',
      'icon': Icons.local_cafe_rounded,
      'color': 0xFF18D4C6,
    },
    {
      'id': 3,
      'name': 'Smart Bookstore',
      'type_ar': 'مكتبة',
      'type_en': 'Bookstore',
      'distance': '700 متر',
      'description_ar': 'مكتبة تبيع كتباً أكاديمية وتقنية',
      'description_en': 'Bookstore selling academic and technical books',
      'icon': Icons.menu_book_rounded,
      'color': 0xFF18D4C6,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '📍 Zameel Campus' : '📍 Zameel Campus',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _showCampusSearch,
              icon: const Icon(Icons.search_rounded),
              tooltip: isArabic ? 'بحث في الحرم' : 'Search campus',
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LiveMapScreen()),
              ),
              icon: const Icon(Icons.navigation_rounded),
              tooltip: isArabic ? 'ابدأ الملاحة' : 'Start navigation',
            ),
          ],
        ),
        body: Column(
          children: [
            // ====================================================
            // TABS
            // ====================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _CampusTabButton(
                    text: isArabic ? '🗺️ الخريطة' : '🗺️ Map',
                    isSelected: selectedTab == 0,
                    onTap: () {
                      setState(() {
                        selectedTab = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _CampusTabButton(
                    text: isArabic ? '🏛️ المباني' : '🏛️ Buildings',
                    isSelected: selectedTab == 1,
                    onTap: () {
                      setState(() {
                        selectedTab = 1;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _CampusTabButton(
                    text: isArabic ? '🛠️ الخدمات' : '🛠️ Services',
                    isSelected: selectedTab == 2,
                    onTap: () {
                      setState(() {
                        selectedTab = 2;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ====================================================
            // CONTENT
            // ====================================================
            Expanded(
              child: selectedTab == 0
                  ? _buildMapTab(isArabic)
                  : selectedTab == 1
                      ? _buildBuildingsTab(isArabic)
                      : _buildServicesTab(isArabic),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAP TAB (الخريطة)
  // ============================================================

  Widget _buildMapTab(bool isArabic) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        child: LiveMapScreen(embedded: true),
      ),
    );
  }

  // ============================================================
  // BUILDINGS TAB (المباني)
  // ============================================================

  Widget _buildBuildingsTab(bool isArabic) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: buildings.length,
      itemBuilder: (context, index) {
        final building = buildings[index];
        final Color color = Color(building['color']);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                building['icon'],
                color: color,
                size: 28,
              ),
            ),
            title: Text(
              isArabic ? building['name_ar'] : building['name_en'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? building['type_ar'] : building['type_en'],
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
                Text(
                  isArabic ? building['description_ar'] : building['description_en'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  '📍 ${building['location']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey,
            ),
            onTap: () {
              _showBuildingDetails(
                context,
                building,
                isArabic,
              );
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // SERVICES TAB (الخدمات)
  // ============================================================

  Widget _buildServicesTab(bool isArabic) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        final Color color = Color(service['color']);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                service['icon'],
                color: color,
                size: 28,
              ),
            ),
            title: Text(
              isArabic ? service['name_ar'] : service['name_en'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? service['type_ar'] : service['type_en'],
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
                Text(
                  isArabic ? service['description_ar'] : service['description_en'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  '📍 ${service['location']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey,
            ),
            onTap: () {
              _showBuildingDetails(
                context,
                service,
                isArabic,
              );
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // دالة عرض تفاصيل المبنى
  // ============================================================

  void _showCampusSearch() {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final q = controller.text.trim().toLowerCase();
          final results = buildings.where((b) {
            final text = '${b['name_ar']} ${b['name_en']} ${b['type_ar']} ${b['type_en']} ${b['location']}'.toLowerCase();
            return q.isEmpty || text.contains(q);
          }).toList();
          return AlertDialog(
            title: Text(isArabic ? '🔍 البحث في الحرم' : '🔍 Campus search'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: isArabic ? 'اسم المبنى أو نوعه أو رمزه' : 'Building, type or code',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 280,
                    child: results.isEmpty
                        ? Center(child: Text(isArabic ? 'لا توجد نتائج' : 'No results'))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, index) {
                              final b = results[index];
                              return ListTile(
                                leading: Icon(b['icon'], color: Color(b['color'])),
                                title: Text(isArabic ? b['name_ar'] : b['name_en']),
                                subtitle: Text('${b['location']} • ${isArabic ? b['type_ar'] : b['type_en']}'),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  _showBuildingDetails(context, b, isArabic);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBuildingDetails(
    BuildContext context,
    Map<String, dynamic> building,
    bool isArabic,
  ) {
    final Color color = Color(building['color']);
    final int students = building['students'] ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    building['icon'],
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isArabic ? building['name_ar'] : building['name_en'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==============================================
                // الوصف
                // ==============================================
                Text(
                  isArabic ? building['description_ar'] : building['description_en'],
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // ==============================================
                // معلومات إضافية
                // ==============================================
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.location_on_rounded,
                        label: isArabic ? 'الموقع' : 'Location',
                        value: building['location'],
                      ),
                      if (students > 0)
                        _InfoRow(
                          icon: Icons.people_rounded,
                          label: isArabic ? 'عدد الطلاب' : 'Students',
                          value: '$students',
                        ),
                      _InfoRow(
                        icon: Icons.height_rounded,
                        label: isArabic ? 'عدد الطوابق' : 'Floors',
                        value: '${building['floors']}',
                      ),
                      _InfoRow(
                        icon: Icons.category_rounded,
                        label: isArabic ? 'النوع' : 'Type',
                        value: isArabic ? building['type_ar'] : building['type_en'],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('إغلاق'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final name = isArabic ? building['name_ar'] : building['name_en'];
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveMapScreen(
                        initialQuery: '$name جامعة',
                        initialDestinationLabel: name.toString(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.navigation_rounded),
                label: Text(isArabic ? 'توجيه داخل التطبيق' : 'Navigate in app'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18D4C6),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// CAMPUS TAB BUTTON
// ============================================================

class _CampusTabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _CampusTabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFF18D4C6)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF18D4C6)
                  : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MAP GRID PAINTER (خلفية الخريطة)
// ============================================================

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    // خطوط أفقية
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // خطوط عمودية
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // مربعات مميزة
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    for (double y = 0; y < size.height; y += 60) {
      for (double x = 0; x < size.width; x += 60) {
        if ((x ~/ 60 + y ~/ 60) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, 60, 60),
            highlightPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// MAP POINT (نقطة على الخريطة)
// ============================================================

Widget _buildMapPoint({
  double? top,
  double? bottom,
  double? left,
  double? right,
  required String label,
  required Color color,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return Positioned(
    top: top,
    bottom: bottom,
    left: left,
    right: right,
    child: GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black45,
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
// STAT CARD (إحصائيات سريعة)
// ============================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BUILDING LIST TILE
// ============================================================

class _BuildingListTile extends StatelessWidget {
  final Map<String, dynamic> building;
  final bool isArabic;

  const _BuildingListTile({
    required this.building,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = Color(building['color']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            building['icon'],
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          isArabic ? building['name_ar'] : building['name_en'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          isArabic ? building['type_ar'] : building['type_en'],
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Colors.grey,
        ),
        onTap: () {
          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          final isArabic = languageProvider.isArabic;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                    ? '📍 ${building['name_ar']} - ${building['location']}'
                    : '📍 ${building['name_en']} - ${building['location']}',
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// INFO ROW
// ============================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NEARBY COMPANY CARD
// ============================================================

class _NearbyCompanyCard extends StatelessWidget {
  final Map<String, dynamic> company;
  final bool isArabic;

  const _NearbyCompanyCard({
    required this.company,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = Color(company['color']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            company['icon'],
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          company['name'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          isArabic
              ? '${company['type_ar']} • ${company['distance']}'
              : '${company['type_en']} • ${company['distance']}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Colors.grey,
        ),
        onTap: () {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(company['name']),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isArabic ? company['type_ar'] : company['type_en']),
                  const SizedBox(height: 8),
                  Text(isArabic ? company['description_ar'] : company['description_en']),
                  const SizedBox(height: 12),
                  Text('📍 ${company['distance']}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(isArabic ? 'إغلاق' : 'Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}