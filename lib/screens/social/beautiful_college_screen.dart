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

class _BeautifulCollegeScreenState extends State<BeautifulCollegeScreen> {
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _entries = [];
  Set<String> _liked = {};
  Map<String, dynamic>? _winner;
  bool _loading = true;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('zameel_college_entries')
          .select('id,user_id,image_path,caption,place_name,university,like_count,cycle_day,created_at,users!zameel_college_entries_user_id_fkey(name,profile_image)')
          .order('like_count', ascending: false)
          .order('created_at');
      final likes = await client.from('zameel_college_likes').select('entry_id').eq('user_id', client.auth.currentUser!.id);
      Map<String, dynamic>? winner;
      final today = _cycleDay();
      final winners = await client.from('zameel_college_winners').select('entry_id').eq('cycle_day', today).limit(1);
      if ((winners as List).isNotEmpty) {
        final id = winners.first['entry_id'].toString();
        for (final raw in rows as List) {
          final entry = Map<String, dynamic>.from(raw as Map);
          if (entry['id'].toString() == id) winner = entry;
        }
      } else if (DateTime.now().hour >= 20) {
        try {
          await client.rpc('zameel_select_college_winner', params: {'p_cycle': today});
          await _load();
          return;
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _entries = List<Map<String, dynamic>>.from(rows);
          _liked = {for (final row in likes as List) row['entry_id'].toString()};
          _winner = winner;
        });
      }
    } catch (error) {
      debugPrint('BeautifulCollege load failed: $error');
      _notice('تعذر تحميل صور التحدي. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cycleDay() {
    final now = DateTime.now();
    final day = now.hour < 7 ? now.subtract(const Duration(days: 1)) : now;
    return '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  Future<void> _createEntry() async {
    if (DateTime.now().hour < 7 || DateTime.now().hour >= 20) {
      _notice('استقبال الصور متاح يوميًا من 7 صباحًا حتى 8 مساءً.');
      return;
    }
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1800);
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
            TextField(controller: place, maxLength: 100, decoration: const InputDecoration(labelText: 'اسم الكلية أو المكان')),
            TextField(controller: caption, maxLength: 240, decoration: const InputDecoration(labelText: 'وصف قصير (اختياري)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نشر')),
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
      final extension = image.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await client.storage.from('beautiful-college').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: extension == 'png' ? 'image/png' : 'image/jpeg'),
      );
      final profile = await client.from('users').select('university').eq('id', user.id).single();
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
      _notice(FeatureControl.errorMessage(error, 'تعذر نشر الصورة. يُسمح بصورة واحدة في كل دورة'));
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
      await Supabase.instance.client.rpc('zameel_toggle_college_like', params: {'p_entry_id': entry['id']});
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
        content: TextField(controller: reason, maxLength: 300, decoration: const InputDecoration(hintText: 'سبب البلاغ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
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
        _notice('تم استلام البلاغ. تُخفى الصورة بعد بلاغين مستقلين.', success: true);
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
      final path = await SocialDailyFileService.saveDownload(
        'zameel_college_${entry['id']}.jpg',
        Uint8List.fromList(response.bodyBytes),
      );
      _notice('تم تنزيل الصورة داخل ملفات Zameel: $path', success: true);
    } catch (_) {
      _notice('تعذر تنزيل الصورة.');
    }
  }

  void _notice(String text, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: success ? Colors.green : null));
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
              child: const Text('🏆 صورة اليوم الفائزة', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          AspectRatio(aspectRatio: 4 / 3, child: Image.network(_url(entry), fit: BoxFit.cover, cacheWidth: 1200)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry['place_name']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text('${entry['university'] ?? ''} • ${user['name'] ?? 'زميل'}', style: const TextStyle(color: Colors.black54)),
                if ((entry['caption']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(entry['caption'].toString()),
                ],
                Row(
                  children: [
                    IconButton(onPressed: () => _like(entry), icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : null)),
                    Text('${entry['like_count'] ?? 0}'),
                    const Spacer(),
                    IconButton(tooltip: 'تنزيل', onPressed: () => _download(entry), icon: const Icon(Icons.download_rounded)),
                    IconButton(tooltip: 'إبلاغ', onPressed: () => _report(entry), icon: const Icon(Icons.flag_outlined)),
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
                decoration: BoxDecoration(gradient: AppTheme.signatureGradient, borderRadius: BorderRadius.circular(22)),
                child: const Column(
                  children: [
                    Text('ورّينا أجمل مكان في جامعتك', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    SizedBox(height: 6),
                    Text('التقديم والتصويت من 7 صباحًا حتى 8 مساءً، ثم تظهر الصورة الفائزة حتى دورة اليوم التالي.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_winner != null) _entryCard(_winner!, winner: true),
              if (_winner != null) const Divider(height: 30),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_entries.isEmpty)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('لا توجد صور في تحدي اليوم بعد.')))
              else
                ..._entries.where((entry) => entry['id'] != _winner?['id']).map(_entryCard),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
