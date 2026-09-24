import 'package:flutter/material.dart';
import '../../services/feature_control.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'package:zameel/theme/app_theme.dart';
import '../../services/remaining_services.dart';
import 'group_chat_screen.dart';

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

  List<Map<String, dynamic>> myGroups = [];
  List<Map<String, dynamic>> discoverGroups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final rows = await RemainingServices.groups();
      final normalized = rows.map(_groupFromRow).toList();
      if (!mounted) return;
      setState(() {
        myGroups = normalized.where((g) => g['isJoined'] == true).toList();
        discoverGroups = normalized.where((g) => g['isJoined'] != true).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _groupFromRow(Map<String, dynamic> row) {
    final type = row['group_type']?.toString() ?? 'other';
    return {
      'id': row['id']?.toString() ?? '',
      'owner_id': row['owner_id']?.toString() ?? '',
      'name_ar': row['name']?.toString() ?? '',
      'name_en': row['name']?.toString() ?? '',
      'type_ar': _groupTypeLabel(type, true),
      'type_en': _groupTypeLabel(type, false),
      'group_type': type,
      'members': (row['members'] as num?)?.toInt() ?? 0,
      'isPrivate': row['is_private'] == true,
      'isJoined': row['is_joined'] == true,
      'isOwner': row['is_owner'] == true,
      'joinStatus': row['join_status']?.toString() ?? 'none',
      'color': AppTheme.primary,
      'description_ar': row['description']?.toString() ?? '',
      'description_en': row['description']?.toString() ?? '',
    };
  }

  String _groupTypeLabel(String type, bool ar) {
    switch (type) {
      case 'graduation_year':
        return ar ? 'دفعة' : 'Graduation Year';
      case 'club':
        return ar ? 'نادي' : 'Club';
      case 'major':
        return ar ? 'تخصص' : 'Major';
      case 'interests':
        return ar ? 'اهتمامات' : 'Interests';
      case 'study':
        return ar ? 'دراسة' : 'Study';
      default:
        return ar ? 'مجموعة' : 'Group';
    }
  }

  String _groupTypeCode(String value) {
    if (value == 'دفعة' || value == 'Graduation Year') return 'graduation_year';
    if (value == 'نادي' || value == 'Club') return 'club';
    if (value == 'تخصص' || value == 'Major') return 'major';
    if (value == 'اهتمامات' || value == 'Interests') return 'interests';
    return 'other';
  }

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
                    style: const TextStyle(color: Colors.black87),
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
                    style: const TextStyle(color: Colors.black87),
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
                        activeColor: AppTheme.primary,
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
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArabic ? 'يرجى إدخال اسم المجموعة' : 'Please enter a group name'),
                      ),
                    );
                    return;
                  }

                  try {
                    final row = await RemainingServices.createGroup(
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim(),
                      type: _groupTypeCode(selectedType),
                      isPrivate: isPrivate,
                    );
                    if (!mounted) return;
                    setState(() {
                      myGroups.insert(0, _groupFromRow(row));
                      selectedTab = 0;
                    });
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArabic ? '✅ تم إنشاء المجموعة بنجاح!' : '✅ Group created successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(FeatureControl.errorMessage(error, isArabic ? 'تعذر إنشاء المجموعة' : 'Could not create group'))),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
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

  Future<void> _joinGroup(Map<String, dynamic> group) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.isArabic;
    try {
      final result = await RemainingServices.joinGroup(group['id']?.toString() ?? '');
      if (!mounted) return;
      await _loadGroups();
      if (!mounted) return;
      final requested = result == 'requested';
      if (!requested) setState(() => selectedTab = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requested
                ? (isArabic
                    ? '📨 تم إرسال طلب الانضمام إلى ${group['name_ar']}'
                    : '📨 Join request sent to ${group['name_en']}')
                : (isArabic
                    ? '✅ تم الانضمام إلى مجموعة ${group['name_ar']}!'
                    : '✅ Joined ${group['name_en']} successfully!'),
          ),
          backgroundColor: requested ? AppTheme.primary : Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FeatureControl.errorMessage(error, isArabic ? 'تعذر الانضمام للمجموعة' : 'Could not join group'))),
      );
    }
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
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
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
              color: AppTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'لا توجد مجموعات' : 'No groups yet',
              style: const TextStyle(
                fontSize: 18,
                color: AppTheme.muted,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic ? 'انضم إلى مجموعات أو أنشئ مجموعتك الخاصة' : 'Join groups or create your own',
              style: const TextStyle(
                color: AppTheme.muted,
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
                  onLeave: () async {
                    try {
                      await RemainingServices.leaveGroup(group['id']?.toString() ?? '');
                      if (!mounted) return;
                      await _loadGroups();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isArabic ? '✅ تم مغادرة المجموعة بنجاح' : '✅ Left group successfully'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            group['isOwner'] == true
                                ? (isArabic ? 'مالك المجموعة لا يمكنه المغادرة قبل نقل الملكية' : 'The group owner cannot leave before transferring ownership')
                                : (isArabic ? 'تعذر مغادرة المجموعة' : 'Could not leave group'),
                          ),
                        ),
                      );
                    }
                  },
                  onDelete: () async {
                    try {
                      await RemainingServices.deleteGroup(group['id']?.toString() ?? '');
                      if (!mounted) return;
                      await _loadGroups();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isArabic ? '🗑️ تم حذف المجموعة' : '🗑️ Group deleted'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isArabic ? 'تعذر حذف المجموعة' : 'Could not delete group')),
                      );
                    }
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
              color: AppTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'لا توجد مجموعات للاكتشاف' : 'No groups to discover',
              style: const TextStyle(
                fontSize: 18,
                color: AppTheme.muted,
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
                    ? AppTheme.primary
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
                  ? AppTheme.primary
                  : AppTheme.muted.shade600,
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
    final isPrivate = group['isPrivate'] == true;
    final requestPending = group['joinStatus'] == 'pending';
    final rawColor = group['color'];
    final Color color = rawColor is Color
        ? rawColor
        : rawColor is int
            ? Color(rawColor)
            : AppTheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.muted.shade200,
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
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isArabic ? group['type_ar'] : group['type_en']} • ${group['members']} ${isArabic ? 'عضو' : 'members'}',
                      style: TextStyle(
                        color: AppTheme.muted.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (showJoinButton && onJoin != null)
                ElevatedButton(
                  onPressed: requestPending ? null : onJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
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
                    requestPending
                        ? (isArabic ? 'قيد الانتظار' : 'Pending')
                        : (isPrivate
                            ? (isArabic ? 'طلب انضمام' : 'Request')
                            : (isArabic ? 'انضمام' : 'Join')),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.muted,
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
  final VoidCallback? onDelete;

  const GroupDetailsScreen({
    super.key,
    required this.group,
    required this.onLeave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final isJoined = group['isJoined'] == true;
    final isOwner = group['isOwner'] == true;
    final rawColor = group['color'];
    final Color color = rawColor is Color
        ? rawColor
        : rawColor is int
            ? Color(rawColor)
            : AppTheme.primary;

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

              if (!isJoined)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    isArabic
                        ? 'انضم إلى المجموعة أولاً لفتح دردشة الأعضاء.'
                        : 'Join the group first to open the members chat.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),

              if (!isJoined) const SizedBox(height: 12),

              // Action Buttons
              if (isJoined)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupChatScreen(
                          groupId: group['id']?.toString() ?? '',
                          groupName: isArabic
                              ? group['name_ar']?.toString() ?? ''
                              : group['name_en']?.toString() ?? '',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
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

              if (isOwner)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    isArabic ? '👑 أنت مالك المجموعة' : '👑 You own this group',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                  ),
                ),

              if (isOwner) const SizedBox(height: 12),

              if (isOwner && onDelete != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: Text(isArabic ? 'حذف المجموعة نهائيًا' : 'Delete Group'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(isArabic ? 'حذف المجموعة' : 'Delete Group'),
                          content: Text(
                            isArabic
                                ? 'سيتم حذف المجموعة ورسائلها وعضوياتها نهائيًا. هل تريد المتابعة؟'
                                : 'The group, its messages and memberships will be permanently deleted. Continue?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                Navigator.pop(context);
                                onDelete?.call();
                              },
                              child: Text(isArabic ? 'حذف' : 'Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              if (isOwner && onDelete != null) const SizedBox(height: 12),

              // Leave Button
              if (isJoined && !isOwner)
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
          color: AppTheme.muted.shade50,
          borderRadius: BorderRadius.circular(14),
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
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.muted.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
