import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';

// ============================================================
// JOBS SCREEN (الوظائف والتدريب)
// ============================================================

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  int selectedFilter = 0; // 0 = الكل, 1 = وظائف, 2 = تدريب, 3 = تدريب صيفي

  final List<Map<String, dynamic>> jobs = [
    {
      'id': 1,
      'title_ar': 'مطور Flutter',
      'title_en': 'Flutter Developer',
      'company': 'Tech Solutions',
      'type_ar': 'وظيفة',
      'type_en': 'Job',
      'location_ar': 'عمّان',
      'location_en': 'Amman',
      'description_ar': 'نبحث عن مطور Flutter للانضمام إلى فريق التطوير',
      'description_en': 'We are looking for a Flutter Developer to join our development team',
      'requirements_ar': 'خبرة في Flutter و Dart، مهارات التواصل الجيد',
      'requirements_en': 'Experience in Flutter and Dart, good communication skills',
      'salary': '500 - 700 JOD',
      'deadline': '2024-07-15',
      'isRemote': false,
      'isUrgent': true,
      'color': 0xFF12AFA5,
    },
    {
      'id': 2,
      'title_ar': 'متدرب هندسة برمجيات',
      'title_en': 'Software Engineering Intern',
      'company': 'Code Academy',
      'type_ar': 'تدريب',
      'type_en': 'Internship',
      'location_ar': 'إربد',
      'location_en': 'Irbid',
      'description_ar': 'فرصة تدريبية لطلاب هندسة البرمجيات',
      'description_en': 'Internship opportunity for Software Engineering students',
      'requirements_ar': 'طالب في السنة الثالثة أو الرابعة، معرفة بأساسيات البرمجة',
      'requirements_en': '3rd or 4th year student, knowledge of programming basics',
      'salary': 'غير مدفوع',
      'deadline': '2024-06-30',
      'isRemote': false,
      'isUrgent': false,
      'color': 0xFFFF9800,
    },
    {
      'id': 3,
      'title_ar': 'تدريب صيفي في الذكاء الاصطناعي',
      'title_en': 'Summer Training in AI',
      'company': 'Innovate Labs',
      'type_ar': 'تدريب صيفي',
      'type_en': 'Summer Training',
      'location_ar': 'عمّان (عن بعد)',
      'location_en': 'Amman (Remote)',
      'description_ar': 'تدريب صيفي مكثف في مجال الذكاء الاصطناعي',
      'description_en': 'Intensive summer training in Artificial Intelligence',
      'requirements_ar': 'معرفة في Python ومكتبات الذكاء الاصطناعي',
      'requirements_en': 'Knowledge of Python and AI libraries',
      'salary': '200 JOD',
      'deadline': '2024-07-01',
      'isRemote': true,
      'isUrgent': false,
      'color': 0xFF2196F3,
    },
    {
      'id': 4,
      'title_ar': 'مصمم واجهات UX/UI',
      'title_en': 'UX/UI Designer',
      'company': 'Design Hub',
      'type_ar': 'وظيفة',
      'type_en': 'Job',
      'location_ar': 'الزرقاء',
      'location_en': 'Zarqa',
      'description_ar': 'مطلوب مصمم واجهات UX/UI للعمل على مشاريع متنوعة',
      'description_en': 'UX/UI Designer needed to work on various projects',
      'requirements_ar': 'خبرة في Figma و Adobe XD، مهارات إبداعية',
      'requirements_en': 'Experience in Figma and Adobe XD, creative skills',
      'salary': '450 - 600 JOD',
      'deadline': '2024-08-01',
      'isRemote': false,
      'isUrgent': false,
      'color': 0xFF9C27B0,
    },
    {
      'id': 5,
      'title_ar': 'متدرب تسويق رقمي',
      'title_en': 'Digital Marketing Intern',
      'company': 'Digital Hub',
      'type_ar': 'تدريب',
      'type_en': 'Internship',
      'location_ar': 'عمّان',
      'location_en': 'Amman',
      'description_ar': 'فرصة تدريب في التسويق الرقمي مع فريق محترف',
      'description_en': 'Internship opportunity in digital marketing with a professional team',
      'requirements_ar': 'معرفة في وسائل التواصل الاجتماعي، مهارات كتابة',
      'requirements_en': 'Knowledge of social media, writing skills',
      'salary': 'غير مدفوع',
      'deadline': '2024-07-20',
      'isRemote': true,
      'isUrgent': true,
      'color': 0xFFE91E63,
    },
    {
      'id': 6,
      'title_ar': 'تدريب صيفي في تطوير الويب',
      'title_en': 'Summer Training in Web Development',
      'company': 'Web Masters',
      'type_ar': 'تدريب صيفي',
      'type_en': 'Summer Training',
      'location_ar': 'إربد',
      'location_en': 'Irbid',
      'description_ar': 'تدريب صيفي في تطوير الويب باستخدام React و Node.js',
      'description_en': 'Summer training in web development using React and Node.js',
      'requirements_ar': 'معرفة في HTML/CSS/JavaScript',
      'requirements_en': 'Knowledge of HTML/CSS/JavaScript',
      'salary': '150 JOD',
      'deadline': '2024-06-25',
      'isRemote': false,
      'isUrgent': false,
      'color': 0xFF4CAF50,
    },
  ];

  List<Map<String, dynamic>> get filteredJobs {
    if (selectedFilter == 0) return jobs;
    final typeMap = {
      1: 'وظيفة',
      2: 'تدريب',
      3: 'تدريب صيفي',
    };
    final type = typeMap[selectedFilter];
    return jobs.where((job) => job['type_ar'] == type).toList();
  }

  void _applyFilter(int index) {
    setState(() {
      selectedFilter = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '💼 الوظائف والتدريب' : '💼 Jobs & Training',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // ====================================================
            // FILTERS
            // ====================================================
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _FilterChip(
                    label: isArabic ? 'الكل' : 'All',
                    isSelected: selectedFilter == 0,
                    onTap: () => _applyFilter(0),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: isArabic ? 'وظائف' : 'Jobs',
                    isSelected: selectedFilter == 1,
                    onTap: () => _applyFilter(1),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: isArabic ? 'تدريب' : 'Internships',
                    isSelected: selectedFilter == 2,
                    onTap: () => _applyFilter(2),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: isArabic ? 'تدريب صيفي' : 'Summer Training',
                    isSelected: selectedFilter == 3,
                    onTap: () => _applyFilter(3),
                  ),
                ],
              ),
            ),

            const Divider(height: 4),

            // ====================================================
            // JOBS LIST
            // ====================================================
            Expanded(
              child: filteredJobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.work_off_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isArabic
                                ? 'لا توجد فرص متاحة حالياً'
                                : 'No opportunities available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isArabic
                                ? 'ترقب الفرص الجديدة قريباً'
                                : 'Check back soon for new opportunities',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredJobs.length,
                      itemBuilder: (context, index) {
                        final job = filteredJobs[index];
                        return _JobCard(
                          job: job,
                          isArabic: isArabic,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JobDetailsScreen(
                                  job: job,
                                  isArabic: isArabic,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FILTER CHIP
// ============================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF12AFA5)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// JOB CARD
// ============================================================

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final bool isArabic;
  final VoidCallback onTap;

  const _JobCard({
    required this.job,
    required this.isArabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = Color(job['color']);
    final bool isUrgent = job['isUrgent'] ?? false;
    final bool isRemote = job['isRemote'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUrgent ? Colors.red.shade200 : Colors.grey.shade200,
          width: isUrgent ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==============================================
              // HEADER
              // ==============================================
              Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      job['type_ar'] == 'وظيفة'
                          ? Icons.work_rounded
                          : Icons.school_rounded,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? job['title_ar'] : job['title_en'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          job['company'],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ==============================================
                  // URGENT BADGE
                  // ==============================================
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isArabic ? 'عاجل' : 'Urgent',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // ==============================================
              // DETAILS
              // ==============================================
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.location_on_rounded,
                    text: isArabic ? job['location_ar'] : job['location_en'],
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: isRemote
                        ? Icons.wifi_rounded
                        : Icons.business_center_rounded,
                    text: isRemote
                        ? (isArabic ? 'عن بعد' : 'Remote')
                        : (isArabic ? 'حضوري' : 'On-site'),
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.access_time_rounded,
                    text: job['deadline'],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ==============================================
              // TYPE & SALARY
              // ==============================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isArabic ? job['type_ar'] : job['type_en'],
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    job['salary'],
                    style: TextStyle(
                      color: const Color(0xFF12AFA5),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// INFO CHIP
// ============================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// JOB DETAILS SCREEN
// ============================================================

class JobDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> job;
  final bool isArabic;

  const JobDetailsScreen({
    super.key,
    required this.job,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = Color(job['color']);
    final bool isUrgent = job['isUrgent'] ?? false;
    final bool isRemote = job['isRemote'] ?? false;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '📋 تفاصيل الفرصة' : '📋 Opportunity Details',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '🔥 عاجل',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      isArabic ? job['title_ar'] : job['title_en'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job['company'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _DetailChip(
                          icon: Icons.location_on_rounded,
                          text: isArabic ? job['location_ar'] : job['location_en'],
                          color: Colors.white,
                        ),
                        _DetailChip(
                          icon: isRemote
                              ? Icons.wifi_rounded
                              : Icons.business_center_rounded,
                          text: isRemote
                              ? (isArabic ? 'عن بعد' : 'Remote')
                              : (isArabic ? 'حضوري' : 'On-site'),
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // DESCRIPTION
              _DetailSection(
                title: isArabic ? '📝 الوصف' : '📝 Description',
                content: isArabic ? job['description_ar'] : job['description_en'],
              ),

              const SizedBox(height: 16),

              // REQUIREMENTS
              _DetailSection(
                title: isArabic ? '📋 المتطلبات' : '📋 Requirements',
                content: isArabic ? job['requirements_ar'] : job['requirements_en'],
              ),

              const SizedBox(height: 16),

              // INFO GRID
              Row(
                children: [
                  Expanded(
                    child: _DetailInfoCard(
                      icon: Icons.attach_money_rounded,
                      label: isArabic ? 'الراتب' : 'Salary',
                      value: job['salary'],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DetailInfoCard(
                      icon: Icons.calendar_today_rounded,
                      label: isArabic ? 'آخر موعد' : 'Deadline',
                      value: job['deadline'],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _DetailInfoCard(
                icon: job['type_ar'] == 'وظيفة'
                    ? Icons.work_rounded
                    : Icons.school_rounded,
                label: isArabic ? 'النوع' : 'Type',
                value: isArabic ? job['type_ar'] : job['type_en'],
              ),

              const SizedBox(height: 24),

              // APPLY BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return Directionality(
                          textDirection: isArabic
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Text(
                              isArabic
                                  ? '✅ تأكيد التقديم'
                                  : '✅ Confirm Application',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              isArabic
                                  ? 'هل أنت متأكد من رغبتك في التقديم على هذه الفرصة؟'
                                  : 'Are you sure you want to apply for this opportunity?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isArabic
                                            ? '✅ تم تقديم طلبك بنجاح!'
                                            : '✅ Your application has been submitted!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF12AFA5),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(isArabic ? 'تأكيد' : 'Confirm'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: Text(
                    isArabic ? '📩 تقديم طلب' : '📩 Apply Now',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF12AFA5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL CHIP
// ============================================================

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _DetailChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: color.withOpacity(0.9),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DETAIL SECTION
// ============================================================

class _DetailSection extends StatelessWidget {
  final String title;
  final String content;

  const _DetailSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// DETAIL INFO CARD
// ============================================================

class _DetailInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Icon(
            icon,
            color: const Color(0xFF12AFA5),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}