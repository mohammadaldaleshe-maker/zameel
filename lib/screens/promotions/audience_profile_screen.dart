import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Demographic data is private to its owner and used for promotion matching.
class AudienceProfileScreen extends StatefulWidget {
  final bool arabic;
  const AudienceProfileScreen({super.key, required this.arabic});
  @override
  State<AudienceProfileScreen> createState() => _AudienceProfileScreenState();
}

class _AudienceProfileScreenState extends State<AudienceProfileScreen> {
  List<Map<String, dynamic>>? _cities;
  DateTime? _birth;
  String? _city, _gender, _error;
  bool _busy = false;
  String t(String ar, String en) => widget.arabic ? ar : en;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = Supabase.instance.client;
      final results = await Future.wait<dynamic>([
        db
            .from('zameel_promotion_locations')
            .select('name,governorate')
            .order('governorate')
            .order('name'),
        db
            .from('zameel_audience_profiles')
            .select('birth_date,city,gender')
            .eq('user_id', db.auth.currentUser!.id)
            .maybeSingle(),
      ]);
      if (!mounted) return;
      final row = results[1] as Map?;
      setState(() {
        _cities = (results[0] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        _birth = DateTime.tryParse(row?['birth_date']?.toString() ?? '');
        _city = row?['city']?.toString();
        _gender = row?['gender']?.toString();
        _error = null;
      });
    } catch (_) {
      if (mounted)
        setState(
            () => _error = t('تعذر تحميل البيانات', 'Unable to load data'));
    }
  }

  Future<void> _selectCity() async {
    var query = '';
    final city = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => SafeArea(
                child: SizedBox(
                    height: MediaQuery.sizeOf(ctx).height * .75,
                    child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextField(
                              decoration: InputDecoration(
                                  hintText: t('بحث عن المدينة', 'Search city'),
                                  prefixIcon: const Icon(Icons.search)),
                              onChanged: (v) =>
                                  update(() => query = v.trim()))),
                      Expanded(
                          child: ListView(children: [
                        for (final c in _cities!
                            .where((c) => c['name'].toString().contains(query)))
                          ListTile(
                              title: Text(c['name'].toString()),
                              subtitle: Text(c['governorate'].toString()),
                              selected: c['name'] == _city,
                              onTap: () =>
                                  Navigator.pop(ctx, c['name'].toString()))
                      ])),
                    ])))));
    if (city != null && mounted) setState(() => _city = city);
  }

  Future<void> _save() async {
    if (_birth == null || _city == null || _gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('أكمل تاريخ الميلاد والمدينة والجنس',
              'Complete birth date, city and gender'))));
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client
          .rpc('zameel_save_audience_profile', params: {
        'p_birth_date':
            '${_birth!.year.toString().padLeft(4, '0')}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}',
        'p_city': _city,
        'p_gender': _gender
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(t('تم حفظ بياناتك الخاصة', 'Private information saved'))));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('تعذر حفظ البيانات. حاول مجددًا.',
                'Unable to save. Try again.'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
          appBar: AppBar(
              title: Text(
                  t('بيانات الجمهور الخاصة', 'Private audience information'))),
          body: _error != null
              ? Center(
                  child: TextButton(
                      onPressed: _load,
                      child:
                          Text('${_error!} — ${t('إعادة المحاولة', 'Retry')}')))
              : _cities == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(padding: const EdgeInsets.all(16), children: [
                      Text(t(
                          'هذه البيانات لا تظهر في ملفك العام. نستخدمها لاختيار المنشورات الممولة المناسبة لك. الإعلانات تستهدف من عمر 18 عامًا فأكثر؛ لن نخمن عمرك أو مدينتك إن لم تكمل البيانات.',
                          'This information is private. It is used to match sponsored posts. Promotions target adults aged 18+. Missing age or city is never guessed.')),
                      const SizedBox(height: 16),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final now = DateTime.now();
                                  final value = await showDatePicker(
                                      context: context,
                                      initialDate: _birth ??
                                          DateTime(now.year - 18, now.month,
                                              now.day),
                                      firstDate: DateTime(1900),
                                      lastDate: now);
                                  if (value != null && mounted)
                                    setState(() => _birth = value);
                                },
                          child: Text(_birth == null
                              ? t('تاريخ الميلاد', 'Birth date')
                              : '${_birth!.year}/${_birth!.month}/${_birth!.day}')),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _busy ? null : _selectCity,
                          child: Text(_city ??
                              t('المدينة داخل الأردن', 'City in Jordan'))),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration:
                              InputDecoration(labelText: t('الجنس', 'Gender')),
                          items: [
                            DropdownMenuItem(
                                value: 'male', child: Text(t('ذكر', 'Male'))),
                            DropdownMenuItem(
                                value: 'female',
                                child: Text(t('أنثى', 'Female')))
                          ],
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _gender = v)),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: _busy ? null : _save,
                          child: Text(t(_busy ? 'جارٍ الحفظ…' : 'حفظ',
                              _busy ? 'Saving…' : 'Save'))),
                    ])));
}
