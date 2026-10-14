import 'package:flutter/material.dart';
import '../../services/device_trust160.dart';
import '../../services/auth_session_service.dart';

class DevicesScreen160 extends StatefulWidget {
  const DevicesScreen160({super.key});
  @override
  State<DevicesScreen160> createState() => _DevicesScreen160State();
}

class _DevicesScreen160State extends State<DevicesScreen160> {
  List<Map<String, dynamic>>? _devices;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows =
          await DeviceTrust160.db.rpc('zameel_devices_list160') as List;
      if (mounted)
        setState(() {
          _devices =
              rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _error = null;
        });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل الأجهزة. أعد المحاولة.');
    }
  }

  Future<void> _revoke(Map<String, dynamic>? device) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(device == null
                    ? 'إلغاء اعتماد جميع الأجهزة؟'
                    : 'إلغاء اعتماد هذا الجهاز؟'),
                content: const Text(
                    'سيُطلب تأكيد البريد قبل السماح بالدخول مجددًا. يشمل ذلك جلسات هذا الجهاز.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأكيد'))
                ]));
    if (yes != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await DeviceTrust160.db
          .rpc('zameel_devices_revoke160', params: {'p_device': device?['id']});
      if (device == null || device['is_current'] == true) {
        await AuthSessionService.signOut();
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        await _load();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إلغاء الاعتماد. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الأجهزة والجلسات')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              'الأجهزة التي أكّدت بريدك عليها. يعرض الاسم نوع الجهاز، ولا يحدد مالكه الفعلي.'),
          const SizedBox(height: 12),
          if (_error != null) ...[
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: _load, child: const Text('إعادة المحاولة'))
          ],
          if (_devices == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          for (final d in _devices ?? <Map<String, dynamic>>[])
            Card(
                child: ListTile(
                    leading: const Icon(Icons.devices),
                    title: Text(
                        '${d['label']}${d['is_current'] == true ? ' — هذا الجهاز' : ''}'),
                    subtitle: Text(d['revoked_at'] != null
                        ? 'أُلغي الاعتماد'
                        : 'معتمد منذ ${DateTime.tryParse('${d['created_at']}')?.toLocal().toString().split('.').first ?? ''}'),
                    trailing: d['revoked_at'] == null
                        ? TextButton(
                            onPressed: _busy ? null : () => _revoke(d),
                            child: const Text('إلغاء الاعتماد'))
                        : null)),
          const SizedBox(height: 16),
          OutlinedButton(
              onPressed: _busy ? null : () => _revoke(null),
              child: const Text('إلغاء اعتماد جميع الأجهزة')),
        ]),
      ));
}
