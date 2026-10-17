import 'package:flutter/material.dart';

import '../../services/remaining_services.dart';
import '../../theme/app_theme.dart';

/// Members of a group. The owner can remove any other member.
class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final bool isOwner;

  const GroupMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isOwner,
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await RemainingServices.groupMembers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _members = rows;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _remove(Map<String, dynamic> member) async {
    final name = member['name']?.toString() ?? 'زميل';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إخراج من المجموعة؟'),
        content: Text(
            'سيتم إخراج «$name» من المجموعة ولن يستطيع الانضمام إليها بنفسه. يمكنك دعوته من جديد لاحقاً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إخراج'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RemainingServices.removeGroupMember(
          widget.groupId, member['user_id']?.toString() ?? '');
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تم إخراج «$name»')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              RemainingServices.groupErrorText(error, 'تعذر إخراج العضو'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('أعضاء ${widget.groupName}'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('تعذر تحميل الأعضاء'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() => _loading = true);
                            _load();
                          },
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final image =
                            member['profile_image']?.toString() ?? '';
                        final isOwnerRow = member['role'] == 'owner';
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: image.startsWith('http')
                                  ? NetworkImage(image)
                                  : null,
                              child: image.startsWith('http')
                                  ? null
                                  : const Icon(Icons.person_rounded),
                            ),
                            title: Text(member['name']?.toString() ?? 'زميل'),
                            subtitle: isOwnerRow ? const Text('مالك المجموعة') : null,
                            trailing: widget.isOwner && !isOwnerRow
                                ? IconButton(
                                    tooltip: 'إخراج من المجموعة',
                                    icon: const Icon(
                                        Icons.person_remove_alt_1_rounded,
                                        color: Colors.red),
                                    onPressed: () => _remove(member),
                                  )
                                : (isOwnerRow
                                    ? const Icon(Icons.verified_rounded,
                                        color: AppTheme.primary)
                                    : null),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
