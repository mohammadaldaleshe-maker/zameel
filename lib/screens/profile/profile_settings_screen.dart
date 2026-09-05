import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import 'package:provider/provider.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final String userId;
  const ProfileSettingsScreen({super.key, required this.userId});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  String _privacy = 'public';
  String _defaultAudience = 'public';
  String _gender = '';
  bool _allowMessages = true;
  bool _allowCalls = true;
  bool _notificationsEnabled = true;
  bool _loading = true;
  bool _saving = false;

  bool get _isOwner =>
      Supabase.instance.client.auth.currentUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isOwner) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select(
              'account_privacy,default_post_audience,gender,allow_messages,allow_calls,notifications_enabled')
          .eq('id', widget.userId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _privacy = row?['account_privacy']?.toString() ?? 'public';
        _defaultAudience =
            row?['default_post_audience']?.toString() ?? 'public';
        _gender = row?['gender']?.toString() ?? '';
        _allowMessages = row?['allow_messages'] as bool? ?? true;
        _allowCalls = row?['allow_calls'] as bool? ?? true;
        _notificationsEnabled =
            row?['notifications_enabled'] as bool? ?? true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_isOwner) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('users').update({
        'account_privacy': _privacy,
        'default_post_audience': _defaultAudience,
        'gender': _gender.isEmpty ? null : _gender,
        'allow_messages': _allowMessages,
        'allow_calls': _allowCalls,
        'notifications_enabled': _notificationsEnabled,
      }).eq('id', widget.userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات الحساب ✓')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الإعدادات: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;

    if (!_isOwner) {
      return Scaffold(
        appBar:
            AppBar(title: Text(ar ? 'إعدادات الحساب' : 'Account settings')),
        body: Center(
          child: Text(
            ar
                ? 'لا يمكنك تعديل إعدادات حساب مستخدم آخر.'
                : 'You cannot edit another user\'s settings.',
          ),
        ),
      );
    }

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4FAF9),
        appBar: AppBar(
          title: Text(ar ? '⚙️ التحكم بحسابي' : '⚙️ My Account Control'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      ar ? 'الخصوصية' : 'Privacy',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ar
                          ? 'كل هذه الإعدادات تخص حسابك أنت فقط.'
                          : 'These settings control your own account only.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    RadioListTile<String>(
                      value: 'public',
                      groupValue: _privacy,
                      onChanged: (v) =>
                          setState(() => _privacy = v ?? 'public'),
                      title: Text(ar ? '🌍 حساب عام' : '🌍 Public account'),
                      subtitle: Text(ar
                          ? 'يمكن للمستخدمين المسجلين الوصول إلى ملفك وفق جمهور كل منشور.'
                          : 'Signed-in users can discover your profile subject to post audience.'),
                    ),
                    RadioListTile<String>(
                      value: 'colleagues',
                      groupValue: _privacy,
                      onChanged: (v) =>
                          setState(() => _privacy = v ?? 'colleagues'),
                      title: Text(ar ? '👥 للزملاء فقط' : '👥 Colleagues only'),
                      subtitle: Text(ar
                          ? 'المستخدمون غير الزملاء لا يمكنهم فتح الملف أو المحتوى المقيد.'
                          : 'Non-colleagues cannot open your profile or restricted content.'),
                    ),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      value: _defaultAudience,
                      decoration: InputDecoration(
                        labelText: ar
                            ? 'جمهور المنشور الافتراضي'
                            : 'Default post audience',
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'public',
                            child: Text(ar ? '🌍 عامة' : 'Public')),
                        DropdownMenuItem(
                            value: 'friends',
                            child: Text(ar ? '🤝 الزملاء' : 'Colleagues')),
                        DropdownMenuItem(
                            value: 'private',
                            child: Text(ar ? '🔒 لي فقط' : 'Only me')),
                      ],
                      onChanged: (v) =>
                          setState(() => _defaultAudience = v ?? 'public'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _allowMessages,
                    onChanged: (v) => setState(() => _allowMessages = v),
                    secondary: const Icon(Icons.chat_bubble_outline_rounded),
                    title: Text(ar ? 'السماح بالرسائل' : 'Allow messages'),
                  ),
                  SwitchListTile(
                    value: _allowCalls,
                    onChanged: (v) => setState(() => _allowCalls = v),
                    secondary: const Icon(Icons.call_rounded),
                    title: Text(ar ? 'السماح بالمكالمات' : 'Allow calls'),
                  ),
                  SwitchListTile(
                    value: _notificationsEnabled,
                    onChanged: (v) =>
                        setState(() => _notificationsEnabled = v),
                    secondary:
                        const Icon(Icons.notifications_active_outlined),
                    title:
                        Text(ar ? 'تفعيل الإشعارات' : 'Enable notifications'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: DropdownButtonFormField<String>(
                      value: _gender.isEmpty ? null : _gender,
                      decoration: InputDecoration(
                        labelText: ar
                            ? 'الفئة الاختيارية للعرض'
                            : 'Optional feed category',
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'female',
                            child: Text(ar ? 'أنثى' : 'Female')),
                        DropdownMenuItem(
                            value: 'male', child: Text(ar ? 'ذكر' : 'Male')),
                        DropdownMenuItem(
                            value: 'other', child: Text(ar ? 'أخرى' : 'Other')),
                      ],
                      onChanged: (v) =>
                          setState(() => _gender = v ?? ''),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_saving
                  ? (ar ? 'جارٍ الحفظ...' : 'Saving...')
                  : (ar ? 'حفظ الإعدادات' : 'Save settings')),
            ),
          ],
        ),
      ),
    );
  }
}
