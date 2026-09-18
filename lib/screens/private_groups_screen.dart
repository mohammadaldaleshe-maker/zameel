import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'package:zameel/theme/app_theme.dart';
import '../services/remaining_services.dart';

// ============================================================
// PRIVATE GROUPS SCREEN - المجموعات الخاصة (معدل)
// ============================================================

class PrivateGroupsScreen extends StatefulWidget {
  const PrivateGroupsScreen({super.key});

  @override
  State<PrivateGroupsScreen> createState() => _PrivateGroupsScreenState();
}

class _PrivateGroupsScreenState extends State<PrivateGroupsScreen> {
  List<Map<String, dynamic>> groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final rows = await RemainingServices.groups();
      if (!mounted) return;
      setState(() {
        groups = rows
            .where((row) => row['is_private'] == true)
            .map((row) => {
                  'id': row['id']?.toString() ?? '',
                  'name_ar': row['name']?.toString() ?? '',
                  'name_en': row['name']?.toString() ?? '',
                  'description_ar': row['description']?.toString() ?? '',
                  'description_en': row['description']?.toString() ?? '',
                  'members': (row['members'] as num?)?.toInt() ?? 0,
                  'isPrivate': true,
                  'isJoined': row['is_joined'] == true,
                  'isOwner': row['is_owner'] == true,
                  'joinStatus': row['join_status']?.toString() ?? 'none',
                  'image': Icons.lock_rounded,
                  'color': AppTheme.primary,
                })
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _createGroup() {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'إنشاء مجموعة خاصة' : 'Create private group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: isArabic ? 'اسم المجموعة' : 'Group name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isArabic ? 'الوصف' : 'Description',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                await RemainingServices.createGroup(
                  name: name,
                  description: descriptionController.text.trim(),
                  type: 'interests',
                  isPrivate: true,
                );
                if (!mounted) return;
                await _loadGroups();
                if (!mounted) return;
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic ? '✅ تم إنشاء المجموعة' : '✅ Group created'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isArabic ? 'تعذر إنشاء المجموعة' : 'Could not create group')),
                );
              }
            },
            child: Text(isArabic ? 'إنشاء' : 'Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleJoin(int index) async {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final group = groups[index];
    final wasJoined = group['isJoined'] == true;
    if (!wasJoined && group['joinStatus'] == 'pending') return;
    try {
      String result = 'left';
      if (wasJoined) {
        await RemainingServices.leaveGroup(group['id']?.toString() ?? '');
      } else {
        result = await RemainingServices.joinGroup(group['id']?.toString() ?? '');
      }
      if (!mounted) return;
      await _loadGroups();
      if (!mounted) return;
      final groupName = isArabic ? group['name_ar'] : group['name_en'];
      final requested = result == 'requested';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasJoined
                ? (isArabic ? '❌ غادرت $groupName' : '❌ Left $groupName')
                : requested
                    ? (isArabic ? '📨 تم إرسال طلب الانضمام إلى $groupName' : '📨 Join request sent to $groupName')
                    : (isArabic ? '✅ انضممت إلى $groupName' : '✅ Joined $groupName'),
          ),
          backgroundColor: wasJoined
              ? Colors.orange
              : requested
                  ? AppTheme.primary
                  : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            group['isOwner'] == true
                ? (isArabic ? 'أنت مالك المجموعة' : 'You own this group')
                : (isArabic ? 'تعذر تحديث العضوية' : 'Could not update membership'),
          ),
        ),
      );
    }
  }

  Future<void> _showJoinRequests(Map<String, dynamic> group) async {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    try {
      final rows = await RemainingServices.groupJoinRequests(group['id']?.toString() ?? '');
      if (!mounted) return;
      final requests = List<Map<String, dynamic>>.from(rows);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(isArabic ? 'طلبات الانضمام' : 'Join requests'),
            content: SizedBox(
              width: 420,
              child: requests.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        isArabic ? 'لا توجد طلبات معلقة' : 'No pending requests',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                          title: Text(request['user_name']?.toString() ?? (isArabic ? 'زميل' : 'Zameel')),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: isArabic ? 'رفض' : 'Reject',
                                onPressed: () async {
                                  await RemainingServices.respondGroupJoinRequest(
                                    request['request_id']?.toString() ?? '',
                                    accept: false,
                                  );
                                  requests.removeAt(index);
                                  setDialogState(() {});
                                },
                                icon: const Icon(Icons.close_rounded, color: Colors.red),
                              ),
                              IconButton(
                                tooltip: isArabic ? 'قبول' : 'Accept',
                                onPressed: () async {
                                  await RemainingServices.respondGroupJoinRequest(
                                    request['request_id']?.toString() ?? '',
                                    accept: true,
                                  );
                                  requests.removeAt(index);
                                  setDialogState(() {});
                                  if (mounted) await _loadGroups();
                                },
                                icon: const Icon(Icons.check_rounded, color: Colors.green),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(isArabic ? 'إغلاق' : 'Close'),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تعذر تحميل طلبات الانضمام' : 'Could not load join requests')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '👥 المجموعات الخاصة' : '👥 Private Groups',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          actions: [
            IconButton(
              onPressed: _createGroup,
              icon: const Icon(Icons.add_rounded),
              tooltip: isArabic ? 'إضافة مجموعة' : 'Add group',
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final rawColor = group['color'];
            final Color color = rawColor is Color
                ? rawColor
                : rawColor is int
                    ? Color(rawColor)
                    : AppTheme.primary;
            final isPrivate = group['isPrivate'] ?? false;
            final isJoined = group['isJoined'] ?? false;
            final isOwner = group['isOwner'] == true;
            final requestPending = group['joinStatus'] == 'pending';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.muted.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      group['image'],
                      color: color,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isArabic ? group['name_ar'] : group['name_en'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isPrivate)
                              Icon(
                                Icons.lock_rounded,
                                size: 14,
                                color: AppTheme.muted.shade400,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isArabic ? group['description_ar'] : group['description_en'],
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.muted.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people_rounded,
                              size: 14,
                              color: AppTheme.muted.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${group['members']} ${isArabic ? 'عضو' : 'members'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.muted.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isOwner) ...[
                    IconButton(
                      onPressed: () => _showJoinRequests(group),
                      tooltip: isArabic ? 'طلبات الانضمام' : 'Join requests',
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        isArabic ? 'المالك' : 'Owner',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                      ),
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: requestPending ? null : () => _toggleJoin(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isJoined ? AppTheme.muted.shade200 : color,
                        foregroundColor: isJoined ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        isJoined
                            ? (isArabic ? 'مغادرة' : 'Leave')
                            : requestPending
                                ? (isArabic ? 'قيد الانتظار' : 'Pending')
                                : (isArabic ? 'طلب انضمام' : 'Request'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isJoined ? AppTheme.muted.shade600 : null,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
