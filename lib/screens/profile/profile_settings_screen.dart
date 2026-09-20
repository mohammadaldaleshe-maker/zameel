import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:zameel/theme/app_theme.dart';
import '../../services/auth_session_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final String userId;
  const ProfileSettingsScreen({super.key, required this.userId});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _username = TextEditingController();
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _university = TextEditingController();
  final _college = TextEditingController();
  final _department = TextEditingController();
  String _privacy = 'public';
  String _defaultAudience = 'public';
  String _gender = '';
  bool _allowMessages = true;
  bool _allowCalls = true;
  bool _notificationsEnabled = true;
  bool _callSoundsEnabled = true;
  bool _notificationSoundsEnabled = true;
  bool _showOnlineStatus = true;
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
          .select('name,email,phone,username,headline,bio,university,college,department,account_privacy,default_post_audience,gender,allow_messages,allow_calls,notifications_enabled,show_online_status,call_sounds_enabled,notification_sounds_enabled')
          .eq('id', widget.userId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _name.text = row?['name']?.toString() ?? '';
        _email.text = row?['email']?.toString() ?? Supabase.instance.client.auth.currentUser?.email ?? '';
        _phone.text = row?['phone']?.toString() ?? '';
        _username.text = row?['username']?.toString() ?? '';
        _headline.text = row?['headline']?.toString() ?? '';
        _bio.text = row?['bio']?.toString() ?? '';
        _university.text = row?['university']?.toString() ?? '';
        _college.text = row?['college']?.toString() ?? '';
        _department.text = row?['department']?.toString() ?? '';
        _privacy = row?['account_privacy']?.toString() ?? 'public';
        _defaultAudience =
            row?['default_post_audience']?.toString() ?? 'public';
        _gender = row?['gender']?.toString() ?? '';
        _allowMessages = row?['allow_messages'] as bool? ?? true;
        _allowCalls = row?['allow_calls'] as bool? ?? true;
        _notificationsEnabled =
            row?['notifications_enabled'] as bool? ?? true;
        _callSoundsEnabled = row?['call_sounds_enabled'] as bool? ?? true;
        _notificationSoundsEnabled = row?['notification_sounds_enabled'] as bool? ?? true;
        _showOnlineStatus = row?['show_online_status'] as bool? ?? true;
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
        'name': _name.text.trim().isEmpty ? 'مستخدم' : _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'username': _username.text.trim().isEmpty ? null : _username.text.trim().toLowerCase(),
        'headline': _headline.text.trim(),
        'bio': _bio.text.trim(),
        'university': _university.text.trim(),
        'college': _college.text.trim(),
        'department': _department.text.trim(),
        'account_privacy': _privacy,
        'default_post_audience': _defaultAudience,
        'allow_messages': _allowMessages,
        'allow_calls': _allowCalls,
        'notifications_enabled': _notificationsEnabled,
        'call_sounds_enabled': _callSoundsEnabled,
        'notification_sounds_enabled': _notificationSoundsEnabled,
        'show_online_status': _showOnlineStatus,
      }).eq('id', widget.userId);

      final authEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
      if (_email.text.trim().isNotEmpty && _email.text.trim() != authEmail) {
        await Supabase.instance.client.auth.updateUser(UserAttributes(email: _email.text.trim()));
      }

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
  void dispose() {
    for (final controller in [_name,_email,_phone,_username,_headline,_bio,_university,_college,_department]) {
      controller.dispose();
    }
    super.dispose();
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
        backgroundColor: AppTheme.background,
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(ar ? 'المعلومات الشخصية والأكاديمية' : 'Personal & academic information', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _field(_name, ar ? 'الاسم الكامل' : 'Full name', Icons.person_rounded),
                  _field(_username, ar ? 'اسم المستخدم' : 'Username', Icons.alternate_email_rounded),
                  _field(_email, ar ? 'البريد الإلكتروني' : 'Email', Icons.email_rounded, keyboard: TextInputType.emailAddress),
                  _field(_phone, ar ? 'رقم الهاتف' : 'Phone number', Icons.phone_rounded, keyboard: TextInputType.phone),
                  _field(_headline, ar ? 'العنوان المختصر' : 'Headline', Icons.badge_rounded),
                  _field(_bio, ar ? 'نبذة عني' : 'Bio', Icons.notes_rounded, lines: 3, maxLength: 160),
                  _field(_university, ar ? 'الجامعة' : 'University', Icons.account_balance_rounded),
                  _field(_college, ar ? 'الكلية' : 'College', Icons.school_rounded),
                  _field(_department, ar ? 'التخصص' : 'Major', Icons.menu_book_rounded),
                ]),
              ),
            ),
            const SizedBox(height: 12),
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
                      style: const TextStyle(color: AppTheme.muted),
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
                    value: _showOnlineStatus,
                    onChanged: (v) => setState(() => _showOnlineStatus = v),
                    secondary: Icon(_showOnlineStatus ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    title: Text(ar ? 'إظهار أنني متصل' : 'Show my online status'),
                    subtitle: Text(ar ? 'عند إيقافه لن تستطيع رؤية حالة اتصال زملائك.' : 'When disabled, you cannot see colleagues’ online status.'),
                  ),
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
                  SwitchListTile(value:_callSoundsEnabled,onChanged:(v)=>setState(()=>_callSoundsEnabled=v),secondary:const Icon(Icons.ring_volume_rounded),title:Text(ar?'نغمات المكالمات':'Call sounds'),subtitle:Text(ar?'رنين المكالمة الواردة ونغمة انتظار المتصل':'Incoming ringtone and caller ringback')),
                  SwitchListTile(value:_notificationSoundsEnabled,onChanged:(v)=>setState(()=>_notificationSoundsEnabled=v),secondary:const Icon(Icons.notifications_active_rounded),title:Text(ar?'صوت إشعارات زميل':'Zameel notification sound')),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(ar ? 'الجنس' : 'Gender'),
                    subtitle: Text(
                      _gender == 'female'
                          ? (ar ? 'أنثى' : 'Female')
                          : _gender == 'male'
                              ? (ar ? 'ذكر' : 'Male')
                              : (ar ? 'غير محدد' : 'Not specified'),
                    ),
                    trailing: Tooltip(
                      message: ar
                          ? 'يثبت بعد إنشاء الحساب. لتصحيح خطأ تواصل مع الدعم.'
                          : 'Locked after registration. Contact support to correct an error.',
                      child: const Icon(Icons.lock_outline_rounded),
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
            const SizedBox(height: 28),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: Text(ar ? 'حذف الحساب' : 'Delete account', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                subtitle: Text(ar ? 'حذف حسابك وبياناته نهائيًا' : 'Permanently delete your account and data'),
                onTap: () => _deleteAccount(ar),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(bool ar) async {
    final confirmation = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ar ? 'حذف الحساب نهائيًا؟' : 'Delete account permanently?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ar ? 'لن تتمكن من استعادة الحساب أو المحتوى بعد الحذف. اكتب «حذف حسابي» للتأكيد.' : 'This cannot be undone. Type DELETE MY ACCOUNT to confirm.'),
          const SizedBox(height: 12),
          TextField(controller: confirmation, decoration: const InputDecoration(border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final expected = ar ? 'حذف حسابي' : 'DELETE MY ACCOUNT';
              Navigator.pop(dialogContext, confirmation.text.trim() == expected);
            },
            child: Text(ar ? 'حذف نهائي' : 'Delete permanently'),
          ),
        ],
      ),
    );
    confirmation.dispose();
    if (approved != true) return;
    try {
      await Supabase.instance.client.rpc('delete_my_account');
      await AuthSessionService.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'تعذر حذف الحساب: $e' : 'Could not delete account: $e')));
    }
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard, int lines = 1, int? maxLength}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: controller, keyboardType: keyboard, minLines: lines, maxLines: lines, maxLength: maxLength,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder())),
  );
}
