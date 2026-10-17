import 'package:flutter/material.dart';

import '../../services/remaining_services.dart';
import '../../theme/app_theme.dart';
import 'group_chat_screen.dart';

/// What a person sees when he is invited to a group, from a notification
/// (`invitationId`) or from a shared link (`inviteCode`). It shows the group
/// card only; nothing inside the group is readable before he accepts.
/// Accepting opens the group, declining returns to the main screen.
class GroupInvitationScreen extends StatefulWidget {
  final String? invitationId;
  final String? inviteCode;

  const GroupInvitationScreen({super.key, this.invitationId, this.inviteCode});

  @override
  State<GroupInvitationScreen> createState() => _GroupInvitationScreenState();
}

class _GroupInvitationScreenState extends State<GroupInvitationScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _missing = false;
  String _groupId = '';
  String _name = '';
  String _description = '';
  String _byline = '';
  String _status = 'pending';
  bool _isPrivate = false;
  bool _isJoined = false;
  bool _isRemoved = false;
  int _members = 0;

  bool get _fromLink => (widget.inviteCode ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (_fromLink) {
        final row = await RemainingServices.groupByInviteCode(widget.inviteCode!);
        if (!mounted) return;
        if (row == null) {
          setState(() {
            _missing = true;
            _loading = false;
          });
          return;
        }
        setState(() {
          _groupId = row['id']?.toString() ?? '';
          _name = row['name']?.toString() ?? '';
          _description = row['description']?.toString() ?? '';
          _byline = 'مالك المجموعة: ${row['owner_name'] ?? 'زميل'}';
          _isPrivate = row['is_private'] == true;
          _isJoined = row['is_joined'] == true;
          _isRemoved = row['is_removed'] == true;
          _members = (row['members'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
        return;
      }
      final row =
          await RemainingServices.groupInvitation(widget.invitationId ?? '');
      if (!mounted) return;
      if (row == null) {
        setState(() {
          _missing = true;
          _loading = false;
        });
        return;
      }
      setState(() {
        _groupId = row['group_id']?.toString() ?? '';
        _name = row['group_name']?.toString() ?? '';
        _description = row['group_description']?.toString() ?? '';
        _byline = 'دعاك ${row['inviter_name'] ?? 'زميل'} للانضمام إلى هذه المجموعة';
        _status = row['status']?.toString() ?? 'pending';
        _isPrivate = row['is_private'] == true;
        _members = (row['members'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _missing = true;
          _loading = false;
        });
      }
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openGroup(String groupId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(groupId: groupId, groupName: _name),
      ),
    );
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final groupId = _fromLink
          ? await RemainingServices.joinGroupByCode(widget.inviteCode!)
          : await RemainingServices.respondGroupInvitation(
              widget.invitationId ?? '',
              accept: true);
      if (!mounted) return;
      _openGroup(groupId.isEmpty ? _groupId : groupId);
    } catch (error) {
      _say(RemainingServices.groupErrorText(error, 'تعذر الانضمام إلى المجموعة'));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!_fromLink) {
        await RemainingServices.respondGroupInvitation(
            widget.invitationId ?? '',
            accept: false);
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      _say(RemainingServices.groupErrorText(error, 'تعذر رفض الدعوة'));
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _message(String text, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_missing) {
      return _message(
        _fromLink
            ? 'رابط الدعوة غير صالح أو تم تغييره.'
            : 'هذه الدعوة لم تعد متاحة.',
        action: TextButton(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('العودة إلى الرئيسية'),
        ),
      );
    }
    final answered = !_fromLink && _status != 'pending';
    final blockedByLink = _fromLink && _isRemoved;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  _isPrivate ? Icons.lock_rounded : Icons.group_rounded,
                  size: 48,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  _name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_isPrivate ? 'مجموعة خاصة' : 'مجموعة عامة'} • $_members عضو',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                if (_description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_description, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _byline,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'لن تستطيع رؤية ما بداخل المجموعة قبل أن توافق على الانضمام.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 24),
          if (blockedByLink)
            const Text(
              'تم إخراجك من هذه المجموعة ولا يمكنك الانضمام إليها بالرابط.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            )
          else if (_fromLink && _isJoined)
            ElevatedButton(
              onPressed: () => _openGroup(_groupId),
              child: const Text('أنت عضو بالفعل، افتح المجموعة'),
            )
          else if (answered)
            Text(
              _status == 'accepted'
                  ? 'سبق أن وافقت على هذه الدعوة.'
                  : 'لم تعد هذه الدعوة متاحة.',
              textAlign: TextAlign.center,
            )
          else ...[
            ElevatedButton(
              onPressed: _busy ? null : _accept,
              child: Text(_busy ? '...' : 'موافق'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _decline,
              child: const Text('رفض'),
            ),
          ],
          if (answered && _status == 'accepted') ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _openGroup(_groupId),
              child: const Text('فتح المجموعة'),
            ),
          ],
          if (answered && _status != 'accepted') ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('العودة إلى الرئيسية'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('دعوة إلى مجموعة')),
        body: _body(),
      ),
    );
  }
}
