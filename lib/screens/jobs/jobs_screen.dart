import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/jobs_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zameel/theme/app_theme.dart';

// ============================================================
// JOBS SCREEN (الوظائف والتدريب)
// ============================================================

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _remoteJobs = [];
  Set<String> _savedJobIds = {};
  bool _remoteLoading = false;
  int selectedFilter = 0; // 0 = الكل, 1 = وظائف, 2 = تدريب, 3 = تدريب صيفي


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final saved = await JobsService.savedIds();
      if (mounted) setState(() => _savedJobIds = saved);
      await _searchRemote();
    });
  }

  List<Map<String, dynamic>> get filteredJobs {
    final source = <Map<String, dynamic>>[..._remoteJobs];
    final query = _searchController.text.trim().toLowerCase();

    final queried = query.isEmpty
        ? source
        : source.where((job) {
            final text =
                '${job['title_en'] ?? ''} ${job['title_ar'] ?? ''} ${job['company'] ?? ''} ${job['location_en'] ?? ''} ${job['location_ar'] ?? ''}'
                    .toLowerCase();
            return text.contains(query);
          }).toList();

    if (selectedFilter == 0) return queried;

    const types = {
      1: 'وظيفة',
      2: 'تدريب',
      3: 'تدريب صيفي',
    };
    final type = types[selectedFilter];
    return queried.where((job) => job['type_ar'] == type).toList();
  }

  Future<void> _searchRemote() async {
    setState(() => _remoteLoading = true);
    try {
      final result = await JobsService.search(
        query: _searchController.text.trim().isEmpty
            ? 'student jobs'
            : _searchController.text.trim(),
        location: 'Jordan',
        results: 20,
      );
      if (mounted) setState(() => _remoteJobs = result);
    } finally {
      if (mounted) setState(() => _remoteLoading = false);
    }
  }

  void _applyFilter(int index) {
    setState(() {
      selectedFilter = index;
    });
  }

  Future<void> _toggleSaved(Map<String, dynamic> job) async {
    final id = JobsService.externalId(job);
    final shouldSave = !_savedJobIds.contains(id);
    setState(() {
      if (shouldSave) {
        _savedJobIds.add(id);
      } else {
        _savedJobIds.remove(id);
      }
    });
    try {
      await JobsService.setSaved(job, shouldSave);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (shouldSave) {
          _savedJobIds.remove(id);
        } else {
          _savedJobIds.add(id);
        }
      });
    }
  }

  Future<void> _openLinkedIn() async {
    final uri = JobsService.linkedInJobsUri(
      query: _searchController.text,
      location: 'Jordan',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _searchRemote(),
                decoration: InputDecoration(
                  hintText: isArabic ? 'ابحث عن وظيفة...' : 'Search jobs...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _remoteLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: _searchRemote,
                          icon: const Icon(Icons.travel_explore_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                ),
              ),
            ),
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

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openLinkedIn,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(
                    isArabic
                        ? 'استكشف فرصًا إضافية على LinkedIn'
                        : 'Explore more opportunities on LinkedIn',
                  ),
                ),
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
                            color: AppTheme.muted.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isArabic
                                ? 'لا توجد فرص متاحة حالياً'
                                : 'No opportunities available',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.muted.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isArabic
                                ? 'ترقب الفرص الجديدة قريباً'
                                : 'Check back soon for new opportunities',
                            style: TextStyle(
                              color: AppTheme.muted.shade500,
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
                          isSaved: _savedJobIds.contains(
                            JobsService.externalId(job),
                          ),
                          onSaved: () => _toggleSaved(job),
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
          color: isSelected ? AppTheme.primary : AppTheme.muted.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.muted.shade700,
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
  final VoidCallback onSaved;
  final bool isSaved;

  const _JobCard({
    required this.job,
    required this.isArabic,
    required this.onTap,
    required this.onSaved,
    required this.isSaved,
  });

  @override
  Widget build(BuildContext context) {
    final rawColor = job['color'];
    final Color color = rawColor is Color
        ? rawColor
        : rawColor is int
            ? Color(rawColor)
            : AppTheme.primary;
    final bool isUrgent = job['isUrgent'] ?? false;
    final bool isRemote = job['isRemote'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUrgent ? Colors.red.shade200 : AppTheme.muted.shade200,
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
                            color: AppTheme.muted.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ==============================================
                  // URGENT BADGE
                  // ==============================================
                  IconButton(
                    tooltip: isArabic ? 'حفظ الفرصة' : 'Save opportunity',
                    onPressed: onSaved,
                    icon: Icon(
                      isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: isSaved ? AppTheme.primary : null,
                    ),
                  ),
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
                      color: AppTheme.primary,
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
          color: AppTheme.muted.shade500,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.muted.shade600,
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
    final rawColor = job['color'];
    final Color color = rawColor is Color
        ? rawColor
        : rawColor is int
            ? Color(rawColor)
            : AppTheme.primary;
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
                          text: isArabic
                              ? job['location_ar']
                              : job['location_en'],
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
                content:
                    isArabic ? job['description_ar'] : job['description_en'],
              ),

              const SizedBox(height: 16),

              // REQUIREMENTS
              _DetailSection(
                title: isArabic ? '📋 المتطلبات' : '📋 Requirements',
                content:
                    isArabic ? job['requirements_ar'] : job['requirements_en'],
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
                  onPressed: () async {
                    final remoteUrl = job['url']?.toString().trim();
                    if (remoteUrl != null && remoteUrl.isNotEmpty) {
                      final uri = Uri.tryParse(remoteUrl);
                      if (uri != null && await canLaunchUrl(uri)) {
                        final launched = await launchUrl(
                          uri,
                          mode: LaunchMode.inAppBrowserView,
                        );
                        if (launched) {
                          await JobsService.recordApplication(job);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isArabic
                                    ? 'تم فتح صفحة الجهة الناشرة. أكمل طلبك لديها مباشرة.'
                                    : 'The publisher page is open. Complete your application there.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                    }
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (context) {
                        return Directionality(
                          textDirection:
                              isArabic ? TextDirection.rtl : TextDirection.ltr,
                          child: AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Text(
                              isArabic
                                  ? 'رابط التقديم غير متاح'
                                  : 'Application link unavailable',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              isArabic
                                  ? 'لم تزود الجهة الناشرة هذه الفرصة برابط تقديم مباشر. يمكنك البحث عنها على LinkedIn، ولن يسجل زميل طلبًا وهميًا.'
                                  : 'The publisher did not provide a direct application link. You can search for it on LinkedIn; Zameel will not record a false submission.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(isArabic ? 'إغلاق' : 'Close'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final linkedIn = JobsService.linkedInJobsUri(
                                    query:
                                        '${job['title_en'] ?? job['title_ar'] ?? ''} ${job['company'] ?? ''}',
                                    location: job['location_en']?.toString() ??
                                        'Jordan',
                                  );
                                  await launchUrl(
                                    linkedIn,
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  isArabic
                                      ? 'البحث على LinkedIn'
                                      : 'Search on LinkedIn',
                                ),
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
                    backgroundColor: AppTheme.primary,
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
            color: AppTheme.muted.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.muted.shade200,
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
        color: AppTheme.muted.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.muted.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppTheme.primary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.muted.shade600,
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
