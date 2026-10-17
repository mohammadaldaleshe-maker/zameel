import 'package:zameel/theme/appearance_controller.dart';
import 'package:flutter/material.dart';
import '../../services/feature_control.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';
import 'lamma_chat_screen.dart';

class LammaScreen extends StatefulWidget {
  const LammaScreen({super.key});
  @override
  State<LammaScreen> createState() => _LammaScreenState();
}

class _LammaScreenState extends State<LammaScreen> {
  final db = Supabase.instance.client;
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _lammas = [];
  Set<String> _myLammaIds = {};
  Map<String, String> _creatorNames = {};

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
    final uid = db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final lammas = await db
          .from('social_lammas')
          .select('*,social_lamma_members(count)')
          .order('created_at', ascending: false)
          .limit(40);
      final memberships = await db
          .from('social_lamma_members')
          .select('lamma_id')
          .eq('user_id', uid);
      final rows = List<Map<String, dynamic>>.from(lammas);
      final names = await _loadCreatorNames(rows);
      if (mounted) {
        setState(() {
          _lammas = rows;
          _myLammaIds = {
            for (final row in memberships as List) row['lamma_id'].toString()
          };
          _creatorNames = names;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _error(e);
      }
    }
  }

  /// Organizer names are optional decoration: a failure here must never stop
  /// the Lamma list itself from loading.
  Future<Map<String, String>> _loadCreatorNames(
      List<Map<String, dynamic>> rows) async {
    final names = <String, String>{};
    try {
      final ids = rows
          .map((l) => l['creator_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (ids.isEmpty) return names;
      final users = await db.from('users').select('id,name').inFilter('id', ids);
      for (final user in (users as List)) {
        final id = user['id']?.toString() ?? '';
        final name = user['name']?.toString().trim() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) names[id] = name;
      }
    } catch (_) {}
    return names;
  }

  void _error(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(FeatureControl.errorMessage(e, 'تعذر إكمال العملية'))));
  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
  bool get _ar =>
      Provider.of<LanguageProvider>(context, listen: false).isArabic;

  Future<void> _createLamma() async {
    final title = TextEditingController();
    var vibe = 'coffee';
    var max = 6;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
                    title: Text(_ar ? 'أنشئ لَمّة' : 'Create a Lamma'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: title,
                          decoration: InputDecoration(
                              labelText: _ar ? 'عنوان بسيط' : 'Short title')),
                      const SizedBox(height: 10),
                      DropdownButtonFormField(
                          value: vibe,
                          items: _vibes.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(_ar ? e.value.$1 : e.value.$2)))
                              .toList(),
                          onChanged: (v) => setLocal(() => vibe = v!),
                          decoration: InputDecoration(
                              labelText: _ar ? 'نوع اللّمّة' : 'Vibe')),
                      const SizedBox(height: 10),
                      DropdownButtonFormField(
                          value: max,
                          items: [3, 4, 5, 6, 7, 8]
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text('$e')))
                              .toList(),
                          onChanged: (v) => setLocal(() => max = v!),
                          decoration: InputDecoration(
                              labelText: _ar ? 'عدد المقاعد' : 'Seats'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(_ar ? 'إلغاء' : 'Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(_ar ? 'إنشاء' : 'Create'))
                    ])));
    if (ok != true || title.text.trim().length < 3) return;
    try {
      final me = await db
          .from('users')
          .select('university,college')
          .eq('id', db.auth.currentUser!.id)
          .single();
      final row = await db
          .from('social_lammas')
          .insert({
            'creator_id': db.auth.currentUser!.id,
            'title': title.text.trim(),
            'vibe': vibe,
            'max_members': max,
            'university': me['university'] ?? '',
            'college': me['college'] ?? ''
          })
          .select('id,title')
          .single();
      final joined =
          await db.rpc('join_social_lamma', params: {'p_lamma': row['id']}) ==
              true;
      if (!joined) throw StateError('join_failed');
      await _load();
      if (mounted) _openLammaChat(row);
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _endLamma(Map<String, dynamic> lamma) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(_ar ? 'إنهاء اللّمّة؟' : 'End this Lamma?'),
                content: Text(_ar
                    ? 'ستختفي اللّمّة من القائمة ولن ينضم إليها أحد بعد الآن.'
                    : 'It will disappear from the list and nobody can join it any more.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(_ar ? 'إلغاء' : 'Cancel')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(_ar ? 'إنهاء' : 'End'))
                ]));
    if (confirmed != true) return;
    try {
      await db
          .from('social_lammas')
          .update({'status': 'ended'})
          .eq('id', lamma['id'])
          .eq('creator_id', db.auth.currentUser!.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_ar ? 'تم إنهاء اللّمّة ✓' : 'Lamma ended ✓')));
      }
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _leaveLamma(Map<String, dynamic> lamma) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(_ar ? 'مغادرة اللّمّة؟' : 'Leave this Lamma?'),
                content: Text(_ar
                    ? 'ستخرج من اللّمّة ولن ترى دردشتها بعد الآن.'
                    : 'You will leave the Lamma and lose access to its chat.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(_ar ? 'إلغاء' : 'Cancel')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(_ar ? 'مغادرة' : 'Leave'))
                ]));
    if (confirmed != true) return;
    try {
      await db.rpc('leave_social_lamma', params: {'p_lamma': lamma['id']});
      await _load();
      if (mounted) _snack(_ar ? 'غادرت اللّمّة ✓' : 'You left the Lamma ✓');
    } catch (e) {
      if (e.toString().contains('creator_cannot_leave')) {
        _snack(_ar
            ? 'منشئ اللّمّة لا يغادرها. يمكنك إنهاؤها بدلًا من ذلك.'
            : 'The creator cannot leave. End the Lamma instead.');
      } else {
        _error(e);
      }
    }
  }

  Future<void> _openLammaChat(Map<String, dynamic> lamma) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LammaChatScreen(
                lammaId: lamma['id'].toString(),
                title: lamma['title']?.toString() ?? 'لَمّة')));
    if (mounted) _load();
  }

  Future<void> _join(Map<String, dynamic> lamma) async {
    final id = lamma['id'].toString();
    if (_myLammaIds.contains(id)) {
      _openLammaChat(lamma);
      return;
    }
    try {
      final ok =
          await db.rpc('join_social_lamma', params: {'p_lamma': lamma['id']}) ==
              true;
      if (!ok) {
        _snack(_ar ? 'اكتمل عدد أعضاء هذه اللّمّة.' : 'This Lamma is full.');
        return;
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(_ar ? 'انضممت إلى اللّمّة ✓' : 'Joined the Lamma ✓')));
        _openLammaChat(lamma);
      }
    } catch (e) {
      if (e.toString().contains('removed_from_lamma')) {
        _snack(_ar
            ? 'تم إخراجك من هذه اللّمّة ولا يمكنك الانضمام إليها.'
            : 'You were removed from this Lamma and cannot rejoin.');
      } else {
        _error(e);
      }
    }
  }

  static const _vibes = <String, (String, String)>{
    'coffee': ('قهوة وتعارف', 'Coffee & chat'),
    'walk': ('مشي داخل الحرم', 'Campus walk'),
    'lunch': ('غداء جماعي', 'Lunch'),
    'games': ('ألعاب وضحك', 'Games'),
    'ideas': ('أفكار ومشاريع', 'Ideas'),
    'new_students': ('طلاب جدد', 'New students'),
    'chill': ('تغيير جو', 'Just chill')
  };

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'لَمّة Zameel' : 'Zameel Lamma')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _lammaTab(ar),
      ),
    );
  }

  List<Map<String, dynamic>> _visibleLammas() {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _lammas;
    return _lammas.where((l) {
      final title = (l['title']?.toString() ?? '').toLowerCase();
      final organizer =
          (_creatorNames[l['creator_id']?.toString() ?? ''] ?? '')
              .toLowerCase();
      return title.contains(query) || organizer.contains(query);
    }).toList();
  }

  Widget _lammaTab(bool ar) {
    final visible = _visibleLammas();
    return RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  gradient: AppTheme.signatureGradient,
                  borderRadius: BorderRadius.circular(20)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ar ? 'دخلت الجامعة وحدك؟' : 'Came to university alone?',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                        ar
                            ? 'Zameel يجد لك اللّمّة المناسبة.'
                            : 'Zameel finds your kind of people.',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primary),
                        onPressed: _createLamma,
                        icon: const Icon(Icons.add),
                        label: Text(ar ? 'أنشئ لَمّة' : 'Create Lamma'))
                  ])),
          const SizedBox(height: 14),
          TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: ar
                      ? 'ابحث باسم اللّمّة أو المنظّم'
                      : 'Search by Lamma or organizer name',
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: ar ? 'مسح' : 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          }))),
          const SizedBox(height: 14),
          if (_lammas.isEmpty)
            Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                    child: Text(ar
                        ? 'لا توجد لَمّات مفتوحة الآن. كن أول من يبدأ.'
                        : 'No open Lammas yet. Start the first one.'))),
          if (_lammas.isNotEmpty && visible.isEmpty)
            Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                    child: Text(ar
                        ? 'لا توجد لَمّات مطابقة للبحث.'
                        : 'No Lammas match your search.'))),
          ...visible.map((l) {
            final raw = l['social_lamma_members'];
            final count =
                raw is List && raw.isNotEmpty ? (raw.first['count'] ?? 0) : 0;
            final vibe = _vibes[l['vibe']] ?? _vibes['chill']!;
            final member = _myLammaIds.contains(l['id'].toString());
            final mine = l['creator_id']?.toString() == db.auth.currentUser?.id;
            final organizer = mine
                ? (ar ? 'أنت' : 'You')
                : (_creatorNames[l['creator_id']?.toString() ?? ''] ?? '');
            final subtitle =
                '${ar ? vibe.$1 : vibe.$2} • $count/${l['max_members']}'
                '${organizer.isEmpty ? '' : '\n${ar ? 'المنظّم' : 'Organizer'}: $organizer'}';
            return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                    onTap: () => _join(l),
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryLight,
                        child: const Icon(Icons.groups_rounded,
                            color: AppTheme.primary)),
                    title: Text(l['title']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(subtitle),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (mine)
                        IconButton(
                            tooltip: ar ? 'إنهاء اللّمّة' : 'End Lamma',
                            icon: const Icon(Icons.stop_circle_outlined,
                                color: Colors.red),
                            onPressed: () => _endLamma(l)),
                      if (member && !mine)
                        IconButton(
                            tooltip: ar ? 'مغادرة اللّمّة' : 'Leave Lamma',
                            icon: const Icon(Icons.logout_rounded,
                                color: Colors.red),
                            onPressed: () => _leaveLamma(l)),
                      FilledButton(
                          onPressed: () => _join(l),
                          child: Text(member
                              ? (ar ? 'دخول' : 'Open')
                              : (ar ? 'انضم' : 'Join')))
                    ])));
          })
        ]));
  }
}
