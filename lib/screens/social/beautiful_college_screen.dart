import 'dart:async';
import '../comments/college_comments161.dart';
import 'package:zameel/theme/appearance_controller.dart';
import 'package:zameel/widgets/verified_name.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/feature_control.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../services/social_daily_file_service.dart';

class BeautifulCollegeScreen extends StatefulWidget {
  const BeautifulCollegeScreen({super.key});

  @override
  State<BeautifulCollegeScreen> createState() => _BeautifulCollegeScreenState();
}

class _BeautifulCollegeScreenState extends State<BeautifulCollegeScreen>
    with WidgetsBindingObserver {
  Timer? _cycleTimer;
  bool _accepting = false;
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _entries = [];
  Set<String> _liked = {};
  Map<String, dynamic>? _winner;
  bool _loading = true;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _cycleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) _load();
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      var snapshot = Map<String, dynamic>.from(
          await client.rpc('zameel_college_snapshot161') as Map);
      if (snapshot['selection_due'] == true && snapshot['winner_id'] == null) {
        await client.rpc('zameel_select_college_winner',
            params: {'p_cycle': snapshot['cycle_day']});
        snapshot = Map<String, dynamic>.from(
            await client.rpc('zameel_college_snapshot161') as Map);
      }
      final rows = List<Map<String, dynamic>>.from(snapshot['entries'] as List);
      final likes = await client
          .from('zameel_college_likes')
          .select('entry_id')
          .eq('user_id', client.auth.currentUser!.id);
      if (mounted)
        setState(() {
          _entries = rows;
          _accepting = snapshot['accepting'] == true;
          _liked = {for (final row in likes) '${row['entry_id']}'};
          _winner = null;
          for (final row in rows) {
            if (row['id'] == snapshot['winner_id']) _winner = row;
          }
        });
    } catch (error) {
      debugPrint('BeautifulCollege load failed: $error');
      _notice('تعذر تحميل صور التحدي. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createEntry() async {
    if (!_accepting) {
      _notice('استقبال الصور متاح يوميًا من 7 صباحًا حتى 8 مساءً.');
      return;
    }
    final image = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 82, maxWidth: 1800);
    if (image == null || !mounted) return;
    final place = TextEditingController();
    final caption = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('شارك جمال جامعتك'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: place,
                maxLength: 100,
                decoration:
                    const InputDecoration(labelText: 'اسم الكلية أو المكان')),
            TextField(
                controller: caption,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                maxLength: 240,
                decoration:
                    const InputDecoration(labelText: 'وصف قصير (اختياري)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نشر')),
        ],
      ),
    );
    if (confirmed != true || place.text.trim().length < 2) {
      place.dispose();
      caption.dispose();
      return;
    }
    setState(() => _publishing = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser!;
      final bytes = await image.readAsBytes();
      final extension =
          image.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final path =
          '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await client.storage.from('beautiful-college').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
                contentType: extension == 'png' ? 'image/png' : 'image/jpeg'),
          );
      final profile = await client
          .from('users')
          .select('university')
          .eq('id', user.id)
          .single();
      await client.from('zameel_college_entries').insert({
        'user_id': user.id,
        'image_path': path,
        'place_name': place.text.trim(),
        'caption': caption.text.trim(),
        'university': profile['university']?.toString() ?? '',
      });
      _notice('تمت إضافة صورتك إلى تحدي اليوم.', success: true);
      await _load();
    } catch (error) {
      _notice(FeatureControl.errorMessage(
          error, 'تعذر نشر الصورة. يُسمح بصورة واحدة في كل دورة'));
    } finally {
      place.dispose();
      caption.dispose();
      if (mounted) setState(() => _publishing = false);
    }
  }

  String _url(Map<String, dynamic> entry) => Supabase.instance.client.storage
      .from('beautiful-college')
      .getPublicUrl(entry['image_path'].toString());

  Future<void> _like(Map<String, dynamic> entry) async {
    try {
      await Supabase.instance.client.rpc('zameel_toggle_college_like',
          params: {'p_entry_id': entry['id']});
      await _load();
    } catch (_) {
      _notice('تعذر تسجيل الإعجاب.');
    }
  }

  Future<void> _report(Map<String, dynamic> entry) async {
    final reason = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الإبلاغ عن الصورة'),
        content: TextField(
            controller: reason,
            maxLength: 300,
            decoration: const InputDecoration(hintText: 'سبب البلاغ')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال')),
        ],
      ),
    );
    if (send == true && reason.text.trim().length >= 2) {
      try {
        await Supabase.instance.client.from('zameel_college_reports').insert({
          'entry_id': entry['id'],
          'reporter_id': Supabase.instance.client.auth.currentUser!.id,
          'reason': reason.text.trim(),
        });
        _notice('تم استلام البلاغ. تُخفى الصورة بعد بلاغين مستقلين.',
            success: true);
        await _load();
      } catch (_) {
        _notice('سبق أن أبلغت عن هذه الصورة أو تعذر إرسال البلاغ.');
      }
    }
    reason.dispose();
  }

  Future<void> _download(Map<String, dynamic> entry) async {
    if (kIsWeb) {
      _notice('استخدم الضغط المطوّل على الصورة لتنزيلها من المتصفح.');
      return;
    }
    try {
      final response = await http.get(Uri.parse(_url(entry)));
      if (response.statusCode != 200) throw Exception('download failed');
      await SocialDailyFileService.saveDownload(
        'zameel_college_${entry['id']}.jpg',
        Uint8List.fromList(response.bodyBytes),
      );
      _notice('تم حفظ الصورة في الاستديو', success: true);
    } catch (_) {
      _notice('تعذر تنزيل الصورة.');
    }
  }

  void _notice(String text, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(text), backgroundColor: success ? Colors.green : null));
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    if (entry['user_id'] != Supabase.instance.client.auth.currentUser?.id)
      return;
    final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) =>
            AlertDialog(title: const Text('حذف مشاركتك؟'), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('حذف'))
            ]));
    if (ok != true || !mounted) return;
    try {
      await Supabase.instance.client
          .from('zameel_college_entries')
          .delete()
          .eq('id', entry['id'])
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);
      await _load();
    } catch (_) {
      _notice('تعذر حذف المشاركة.');
    }
  }

  Widget _entryCard(Map<String, dynamic> entry, {bool winner = false}) {
    final rawUser = entry['users'];
    final user = rawUser is Map ? rawUser : const <String, dynamic>{};
    final liked = _liked.contains(entry['id'].toString());
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (winner)
            Container(
              width: double.infinity,
              color: Colors.amber.shade700,
              padding: const EdgeInsets.all(10),
              child: Text('🏆 صورة اليوم الفائزة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(_url(entry),
                  fit: BoxFit.cover, cacheWidth: 1200)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry['place_name']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                VerifiedName(
                    userId: entry['user_id']?.toString(),
                    child: Text(
                        '${entry['university'] ?? ''} • ${user['name'] ?? 'زميل'}',
                        style: TextStyle(color: AppTheme.adaptiveSecondary))),
                if ((entry['caption']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(entry['caption'].toString()),
                ],
                Row(
                  children: [
                    IconButton(
                        onPressed: () => _like(entry),
                        icon: Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            color: liked ? Colors.red : null)),
                    Text('${entry['like_count'] ?? 0}'),
                    IconButton(
                        tooltip: 'التعليقات',
                        icon: const Icon(Icons.comment_outlined),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CollegeComments161(
                                    entryId: '${entry['id']}',
                                    ownerId: '${entry['user_id']}')))),
                    const Spacer(),
                    if (entry['user_id'] ==
                        Supabase.instance.client.auth.currentUser?.id)
                      IconButton(
                          tooltip: 'حذف مشاركتي',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteEntry(entry)),
                    IconButton(
                        tooltip: 'تنزيل',
                        onPressed: () => _download(entry),
                        icon: const Icon(Icons.download_rounded)),
                    IconButton(
                        tooltip: 'إبلاغ',
                        onPressed: () => _report(entry),
                        icon: const Icon(Icons.flag_outlined)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تحدي أجمل كلية')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _publishing ? null : _createEntry,
          icon: const Icon(Icons.add_a_photo_rounded),
          label: Text(_publishing ? 'جارٍ النشر...' : 'شارك صورة'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    gradient: AppTheme.signatureGradient,
                    borderRadius: BorderRadius.circular(22)),
                child: Column(
                  children: [
                    Text('ورّينا أجمل مكان في جامعتك',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 6),
                    Text(
                        'التقديم والتصويت من 7 صباحًا حتى 8 مساءً، ثم تظهر الصورة الفائزة حتى دورة اليوم التالي.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_winner != null) _entryCard(_winner!, winner: true),
              if (_winner != null) const Divider(height: 30),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_entries.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child:
                        Center(child: Text('لا توجد صور في تحدي اليوم بعد.')))
              else
                ..._entries
                    .where((entry) => entry['id'] != _winner?['id'])
                    .map(_entryCard),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
