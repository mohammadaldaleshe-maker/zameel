import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/remaining_services.dart';
import '../../theme/app_theme.dart';

/// "Invite" sheet of a group: the shareable link, and a searchable list of the
/// user's colleagues to send an in-app invitation to.
Future<void> showGroupInviteSheet(
  BuildContext context, {
  required String groupId,
  required String groupName,
  required bool isOwner,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _GroupInviteSheet(
      groupId: groupId,
      groupName: groupName,
      isOwner: isOwner,
    ),
  );
}

class _GroupInviteSheet extends StatefulWidget {
  final String groupId;
  final String groupName;
  final bool isOwner;

  const _GroupInviteSheet({
    required this.groupId,
    required this.groupName,
    required this.isOwner,
  });

  @override
  State<_GroupInviteSheet> createState() => _GroupInviteSheetState();
}

class _GroupInviteSheetState extends State<_GroupInviteSheet> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _colleagues = [];
  final Map<String, String> _results = {};
  final Set<String> _busy = {};
  String? _link;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    String? link;
    var colleagues = <Map<String, dynamic>>[];
    try {
      link = await RemainingServices.groupInviteLink(widget.groupId);
    } catch (_) {}
    try {
      colleagues = await RemainingServices.colleaguesToInvite();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _link = link;
      _colleagues = colleagues;
      _loading = false;
    });
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _shareText =>
      'ادعوك للانضمام إلى مجموعة «${widget.groupName}» في زميل\n${_link ?? ''}';

  Future<void> _copy() async {
    final link = _link;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    _say('تم نسخ الرابط');
  }

  Future<void> _share() async {
    if (_link == null) return;
    try {
      await SharePlus.instance.share(ShareParams(text: _shareText));
    } catch (_) {
      _say('تعذرت المشاركة');
    }
  }

  Future<void> _resetLink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغيير رابط الدعوة؟'),
        content: const Text(
            'سيتوقف الرابط القديم عن العمل، ولن يستطيع به أحد الانضمام بعد الآن.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تغيير'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final link = await RemainingServices.resetGroupInviteLink(widget.groupId);
      if (!mounted) return;
      setState(() => _link = link);
      _say('تم تغيير الرابط');
    } catch (error) {
      _say(RemainingServices.groupErrorText(error, 'تعذر تغيير الرابط'));
    }
  }

  Future<void> _invite(Map<String, dynamic> person) async {
    final id = person['id']?.toString() ?? '';
    if (id.isEmpty || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final result =
          await RemainingServices.sendGroupInvitation(widget.groupId, id);
      if (!mounted) return;
      setState(() => _results[id] = result);
    } catch (error) {
      _say(RemainingServices.groupErrorText(error, 'تعذر إرسال الدعوة'));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  String _resultLabel(String result) {
    if (result == 'already_member') return 'عضو بالفعل';
    if (result == 'already_invited') return 'مدعو مسبقاً';
    return 'تمت الدعوة';
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = _colleagues.where((person) {
      if (query.isEmpty) return true;
      return (person['name']?.toString() ?? '').toLowerCase().contains(query);
    }).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'دعوة إلى «${widget.groupName}»',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _link ?? (_loading ? '...' : 'تعذر تجهيز الرابط'),
                        textDirection: TextDirection.ltr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: [
                          TextButton.icon(
                            onPressed: _link == null ? null : _copy,
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('نسخ'),
                          ),
                          TextButton.icon(
                            onPressed: _link == null ? null : _share,
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text('مشاركة'),
                          ),
                          if (widget.isOwner)
                            TextButton.icon(
                              onPressed: _link == null ? null : _resetLink,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('تغيير الرابط'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'ابحث في زملائك',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : visible.isEmpty
                          ? Center(
                              child: Text(
                                _colleagues.isEmpty
                                    ? 'لا يوجد زملاء لدعوتهم بعد'
                                    : 'لا توجد نتائج',
                              ),
                            )
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final person = visible[index];
                                final id = person['id']?.toString() ?? '';
                                final image =
                                    person['profile_image']?.toString() ?? '';
                                final result = _results[id];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundImage: image.startsWith('http')
                                        ? NetworkImage(image)
                                        : null,
                                    child: image.startsWith('http')
                                        ? null
                                        : const Icon(Icons.person_rounded),
                                  ),
                                  title: Text(person['name']?.toString() ?? 'زميل'),
                                  trailing: result != null
                                      ? Text(
                                          _resultLabel(result),
                                          style: const TextStyle(
                                              color: AppTheme.muted),
                                        )
                                      : FilledButton(
                                          onPressed: _busy.contains(id)
                                              ? null
                                              : () => _invite(person),
                                          child: Text(_busy.contains(id)
                                              ? '...'
                                              : 'دعوة'),
                                        ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
