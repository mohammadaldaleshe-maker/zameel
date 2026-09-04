import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../chat/chat_screen.dart';

// ============================================================
// GROUPS SCREEN
// ============================================================

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  int selectedTab = 0; // 0 = My Groups, 1 = Discover

  List<Map<String, dynamic>> myGroups = [
    {
      'id': 1,
      'name_ar': 'دفعة 2024',
      'name_en': 'Class of 2024',
      'type_ar': 'دفعة',
      'type_en': 'Graduation Year',
      'members': 45,
      'isPrivate': false,
      'color': 0xFF12AFA5,
      'description_ar': 'مجموعة طلاب دفعة 2024 في الجامعة الأردنية',
      'description_en': 'Group for students of the class of 2024 at the University of Jordan',
    },
    {
      'id': 2,
      'name_ar': 'نادي البرمجة',
      'name_en': 'Programming Club',
      'type_ar': 'نادي',
      'type_en': 'Club',
      'members': 78,
      'isPrivate': false,
      'color': 0xFF2196F3,
      'description_ar': 'نادي البرمجة والتطوير في الجامعة الأردنية',
      'description_en': 'Programming and Development Club at the University of Jordan',
    },
    {
      'id': 3,
      'name_ar': 'هندسة البرمجيات',
      'name_en': 'Software Engineering',
      'type_ar': 'تخصص',
      'type_en': 'Major',
      'members': 120,
      'isPrivate': false,
      'color': 0xFFFF9800,
      'description_ar': 'مجموعة طلاب تخصص هندسة البرمجيات',
      'description_en': 'Group for Software Engineering students',
    },
  ];

  List<Map<String, dynamic>> discoverGroups = [
    {
      'id': 4,
      'name_ar': 'نادي التصميم',
      'name_en': 'Design Club',
      'type_ar': 'نادي',
      'type_en': 'Club',
      'members': 34,
      'isPrivate': true,
      'color': 0xFFE91E63,
      'description_ar': 'نادي التصميم الجرافيكي والUI/UX',
      'description_en': 'Graphic Design and UI/UX Club',
    },
    {
      'id': 5,
      'name_ar': 'دفعة 2023',
      'name_en': 'Class of 2023',
      'type_ar': 'دفعة',
      'type_en': 'Graduation Year',
      'members': 67,
      'isPrivate': false,
      'color': 0xFF9C27B0,
      'description_ar': 'مجموعة طلاب دفعة 2023',
      'description_en': 'Group for students of the class of 2023',
    },
    {
      'id': 6,
      'name_ar': 'نادي الروبوتيكس',
      'name_en': 'Robotics Club',
      'type_ar': 'نادي',
      'type_en': 'Club',
      'members': 23,
      'isPrivate': true,
      'color': 0xFF4CAF50,
      'description_ar': 'نادي الروبوتيكس والذكاء الاصطناعي',
      'description_en': 'Robotics and Artificial Intelligence Club',
    },
  ];

  // ============================================================
  // إنشاء مجموعة جديدة
  // ============================================================

  void _createGroup() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.isArabic;

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = isArabic ? 'دفعة' : 'Graduation Year';
    bool isPrivate = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(
              isArabic ? 'إنشاء مجموعة جديدة' : 'Create a New Group',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'اسم المجموعة' : 'Group Name',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'نوع المجموعة' : 'Group Type',
                      border: const OutlineInputBorder(),
                    ),
                    items: isArabic
                        ? const [
                            DropdownMenuItem(value: 'دفعة', child: Text('📚 دفعة')),
                            DropdownMenuItem(value: 'نادي', child: Text('🏀 نادي')),
                            DropdownMenuItem(value: 'تخصص', child: Text('📖 تخصص')),
                            DropdownMenuItem(value: 'اهتمامات', child: Text('❤️ اهتمامات')),
                          ]
                        : const [
                            DropdownMenuItem(value: 'Graduation Year', child: Text('📚 Graduation Year')),
                            DropdownMenuItem(value: 'Club', child: Text('🏀 Club')),
                            DropdownMenuItem(value: 'Major', child: Text('📖 Major')),
                            DropdownMenuItem(value: 'Interests', child: Text('❤️ Interests')),
                          ],
                    onChanged: (value) {
                      if (value != null) {
                        selectedType = value;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'وصف المجموعة (اختياري)' : 'Group Description (Optional)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(isArabic ? 'خاصة' : 'Private'),
                      const SizedBox(width: 8),
                      Switch(
                        value: isPrivate,
                        onChanged: (value) {
                          isPrivate = value;
                          (dialogContext as Element).markNeedsBuild();
                        },
                        activeColor: const Color(0xFF12AFA5),
                      ),
                      Text(isArabic ? 'عامة' : 'Public'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArabic ? 'يرجى إدخال اسم المجموعة' : 'Please enter a group name'),
                      ),
                    );
                    return;
                  }

                  final newGroup = {
                    'id': DateTime.now().millisecondsSinceEpoch,
                    'name_ar': nameController.text.trim(),
                    'name_en': nameController.text.trim(),
                    'type_ar': selectedType,
                    'type_en': selectedType, // سنعتبرها متطابقة حالياً حتى يعدلها المستخدم
                    'members': 1,
                    'isPrivate': isPrivate,
                    'color': 0xFF12AFA5,
                    'description_ar': descriptionController.text.trim().isEmpty
                        ? 'لا يوجد وصف'
                        : descriptionController.text.trim(),
                    'description_en': descriptionController.text.trim().isEmpty
                        ? 'No description'
                        : descriptionController.text.trim(),
                  };

                  setState(() {
                    myGroups.insert(0, newGroup);
                    selectedTab = 0;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isArabic ? '✅ تم إنشاء المجموعة بنجاح!' : '✅ Group created successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  Navigator.pop(dialogContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF12AFA5),
                  foregroundColor: Colors.white,
                ),
                child: Text(isArabic ? 'إنشاء' : 'Create'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // الانضمام إلى مجموعة (من الاكتشاف)
  // ============================================================

  void _joinGroup(Map<String, dynamic> group) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.isArabic;

    setState(() {
      discoverGroups.removeWhere((g) => g['id'] == group['id']);
      group['members'] = (group['members'] as int) + 1;
      myGroups.insert(0, group);
      selectedTab = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic
              ? '✅ تم الانضمام إلى مجموعة ${group['name_ar']}!'
              : '✅ Joined ${group['name_en']} successfully!',
        ),
        backgroundColor: Colors.green,
      ),
    );
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
            isArabic ? 'المجموعات' : 'Groups',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _createGroup,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _GroupTabButton(
                    text: isArabic ? 'مجموعاتي (${myGroups.length})' : 'My Groups (${myGroups.length})',
                    isSelected: selectedTab == 0,
                    onTap: () {
                      setState(() {
                        selectedTab = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _GroupTabButton(
                    text: isArabic ? 'اكتشاف (${discoverGroups.length})' : 'Discover (${discoverGroups.length})',
                    isSelected: selectedTab == 1,
                    onTap: () {
                      setState(() {
                        selectedTab = 1;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: selectedTab == 0
                  ? _buildMyGroups()
                  : _buildDiscoverGroups(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MY GROUPS
  // ============================================================

  Widget _buildMyGroups() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    if (myGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.group_off_rounded,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'لا توجد مجموعات' : 'No groups yet',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic ? 'انضم إلى مجموعات أو أنشئ مجموعتك الخاصة' : 'Join groups or create your own',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: myGroups.length,
      itemBuilder: (context, index) {
        final group = myGroups[index];
        return _GroupCard(
          group: group,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailsScreen(
                  group: group,
                  onLeave: () {
                    setState(() {
                      myGroups.removeWhere((g) => g['id'] == group['id']);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArabic ? '✅ تم مغادرة المجموعة بنجاح' : '✅ Left group successfully'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DISCOVER GROUPS
  // ============================================================

  Widget _buildDiscoverGroups() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    if (discoverGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'لا توجد مجموعات للاكتشاف' : 'No groups to discover',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: discoverGroups.length,
      itemBuilder: (context, index) {
        final group = discoverGroups[index];
        return _GroupCard(
          group: group,
          showJoinButton: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailsScreen(
                  group: group,
                  onLeave: () {},
                ),
              ),
            );
          },
          onJoin: () => _joinGroup(group),
        );
      },
    );
  }
}

// ============================================================
// GROUP TAB BUTTON
// ============================================================

class _GroupTabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupTabButton({
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
                    ? const Color(0xFF12AFA5)
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
                  ? const Color(0xFF12AFA5)
                  : Colors.grey.shade600,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// GROUP CARD
// ============================================================

class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTap;
  final bool showJoinButton;
  final VoidCallback? onJoin;

  const _GroupCard({
    required this.group,
    required this.onTap,
    this.showJoinButton = false,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final Color color = Color(group['color']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  group['isPrivate'] ?? false
                      ? Icons.lock_rounded
                      : Icons.group_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? group['name_ar'] : group['name_en'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isArabic ? group['type_ar'] : group['type_en']} • ${group['members']} ${isArabic ? 'عضو' : 'members'}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (showJoinButton && onJoin != null)
                ElevatedButton(
                  onPressed: onJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF12AFA5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isArabic ? 'انضمام' : 'Join',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// GROUP DETAILS SCREEN
// ============================================================

class GroupDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onLeave;

  const GroupDetailsScreen({
    super.key,
    required this.group,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final Color color = Color(group['color']);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? 'تفاصيل المجموعة' : 'Group Details',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            group['isPrivate'] ?? false
                                ? Icons.lock_rounded
                                : Icons.group_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic ? group['name_ar'] : group['name_en'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${isArabic ? group['type_ar'] : group['type_en']} • ${group['members']} ${isArabic ? 'عضو' : 'members'}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isArabic ? group['description_ar'] : group['description_en'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Info Cards
              Row(
                children: [
                  _InfoCard(
                    icon: Icons.people_rounded,
                    label: isArabic ? 'الأعضاء' : 'Members',
                    value: '${group['members']}',
                  ),
                  const SizedBox(width: 12),
                  _InfoCard(
                    icon: group['isPrivate'] ?? false
                        ? Icons.lock_rounded
                        : Icons.public_rounded,
                    label: isArabic ? 'الخصوصية' : 'Privacy',
                    value: group['isPrivate'] ?? false
                        ? (isArabic ? 'خاصة' : 'Private')
                        : (isArabic ? 'عامة' : 'Public'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF12AFA5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isArabic ? '💬 الدردشة مع المجموعة' : '💬 Chat with the Group',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Leave Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) {
                        return Directionality(
                          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                          child: AlertDialog(
                            title: Text(
                              isArabic ? 'تأكيد المغادرة' : 'Confirm Leave',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            content: Text(
                              isArabic
                                  ? 'هل أنت متأكد من رغبتك في مغادرة مجموعة "${group['name_ar']}"؟'
                                  : 'Are you sure you want to leave "${group['name_en']}"?',
                              style: const TextStyle(fontSize: 15, height: 1.5),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  Navigator.pop(context);
                                  onLeave();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(isArabic ? 'تأكيد المغادرة' : 'Confirm Leave'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: Text(
                    isArabic ? 'مغادرة المجموعة' : 'Leave Group',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
// INFO CARD
// ============================================================

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
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
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}