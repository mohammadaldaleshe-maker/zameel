import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../services/social_daily_file_service.dart';

class ZameelRadioScreen extends StatefulWidget {
  const ZameelRadioScreen({super.key});

  @override
  State<ZameelRadioScreen> createState() => _ZameelRadioScreenState();
}

class _ZameelRadioScreenState extends State<ZameelRadioScreen> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _recording = false;
  bool _anonymous = false;
  bool _publishing = false;
  int _seconds = 0;
  String? _recordPath;
  String? _playingId;
  String? _loadingPlayId;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      final completedId = _playingId;
      setState(() => _playingId = null);
      final index = _posts.indexWhere((post) => post['id'].toString() == completedId);
      if (index >= 0 && index + 1 < _posts.length) {
        _play(_posts[index + 1], forcePlay: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client.rpc('zameel_radio_feed');
      if (mounted) setState(() => _posts = List<Map<String, dynamic>>.from(rows));
    } catch (error) {
      _notice('تعذر تحميل راديو زميل: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (kIsWeb) {
      _notice('التسجيل الصوتي متاح حاليًا على تطبيق الهاتف.');
      return;
    }
    if (_recording) {
      final path = await _recorder.stop();
      _timer?.cancel();
      setState(() {
        _recording = false;
        _recordPath = path;
      });
      return;
    }
    if (!await _recorder.hasPermission()) {
      _notice('اسمح لـ Zameel باستخدام الميكروفون للتسجيل.');
      return;
    }
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/zameel_radio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _seconds = 0;
      _recordPath = null;
      _recording = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || !_recording) return;
      setState(() => _seconds++);
      if (_seconds >= 120) await _toggleRecording();
    });
  }

  DateTime _nextReset() {
    final now = DateTime.now();
    var reset = DateTime(now.year, now.month, now.day, 7);
    if (!reset.isAfter(now)) reset = reset.add(const Duration(days: 1));
    return reset;
  }

  Future<void> _publish() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _recordPath == null || _seconds < 1 || _publishing) return;
    setState(() => _publishing = true);
    try {
      final path = '${DateTime.now().microsecondsSinceEpoch}_${user.id.hashCode.abs()}.m4a';
      final bytes = await SocialDailyFileService.readPathBytes(_recordPath!);
      await Supabase.instance.client.storage.from('zameel-radio').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'audio/mp4', upsert: false),
      );
      await Supabase.instance.client.from('zameel_radio_posts').insert({
        'user_id': user.id,
        'storage_path': path,
        'duration_seconds': _seconds.clamp(1, 120),
        'is_anonymous': _anonymous,
        'expires_at': _nextReset().toUtc().toIso8601String(),
      });
      setState(() {
        _recordPath = null;
        _seconds = 0;
      });
      _notice('تم نشر المقطع حتى الساعة 7 صباحًا.', success: true);
      await _load();
    } catch (error) {
      _notice('تعذر نشر التسجيل: $error');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _play(Map<String, dynamic> post, {bool forcePlay = false}) async {
    final id = post['id'].toString();
    if (!forcePlay && _playingId == id) {
      await _player.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    if (_loadingPlayId == id) return;
    setState(() {
      _loadingPlayId = id;
      _playingId = id;
    });
    try {
      await _player.stop();
      final url = await Supabase.instance.client.storage
          .from('zameel-radio')
          .createSignedUrl(post['storage_path'].toString(), 600);
      await _player.play(UrlSource(url));
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
      _notice('تعذر تشغيل هذا المقطع.');
    } finally {
      if (mounted) setState(() => _loadingPlayId = null);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    try {
      await Supabase.instance.client.rpc('zameel_toggle_radio_like', params: {'p_post_id': post['id']});
      await _load();
    } catch (_) {
      _notice('تعذر تحديث الإعجاب الآن.');
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التسجيل؟'),
        content: const Text('سيختفي التسجيل من الراديو فورًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await Supabase.instance.client.rpc('zameel_remove_radio_post', params: {'p_post_id': post['id']});
      if (_playingId == post['id'].toString()) await _player.stop();
      _notice('تم حذف التسجيل.', success: true);
      await _load();
    } catch (_) {
      _notice('لا تملك صلاحية حذف هذا التسجيل.');
    }
  }

  Future<void> _reviewPost(Map<String, dynamic> post, bool restore) async {
    try {
      await Supabase.instance.client.rpc('zameel_admin_review_radio', params: {
        'p_post_id': post['id'],
        'p_action': restore ? 'restore' : 'remove',
      });
      _notice(restore ? 'تمت إعادة التسجيل.' : 'تم حذف التسجيل بعد المراجعة.', success: true);
      await _load();
    } catch (_) {
      _notice('هذا الإجراء متاح للإدارة فقط.');
    }
  }

  Future<void> _adminMute(Map<String, dynamic> post) async {
    try {
      await Supabase.instance.client.rpc('zameel_admin_mute_radio_author', params: {'p_post_id': post['id']});
      _notice('تم كتم صاحب التسجيل إداريًا لمدة أسبوع.', success: true);
      await _load();
    } catch (_) {
      _notice('هذا الإجراء متاح للإدارة فقط.');
    }
  }

  Future<void> _report(Map<String, dynamic> post) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الإبلاغ عن المقطع'),
        content: TextField(controller: controller, maxLength: 300, decoration: const InputDecoration(hintText: 'سبب البلاغ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('إرسال')),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.length < 2) return;
    try {
      await Supabase.instance.client.from('zameel_radio_reports').insert({
        'post_id': post['id'],
        'reporter_id': Supabase.instance.client.auth.currentUser!.id,
        'reason': reason,
      });
      _notice('تم استلام البلاغ. يُخفى المقطع تلقائيًا بعد بلاغين مستقلين.', success: true);
      await _load();
    } catch (_) {
      _notice('سبق أن أبلغت عن هذا المقطع أو تعذر إرسال البلاغ.');
    }
  }

  void _notice(String text, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: success ? Colors.green : null));
  }

  String _duration(int seconds) => '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('راديو Zameel')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: AppTheme.signatureGradient, borderRadius: BorderRadius.circular(22)),
                child: Column(
                  children: [
                    const Text('صوت الجامعة ليوم واحد', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('موقف مضحك أو قصة قصيرة بحد أقصى دقيقتين. تُحذف الدورة يوميًا الساعة 7 صباحًا.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 14),
                    Text(_duration(_seconds), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _recording ? Colors.red : AppTheme.primary),
                      onPressed: _publishing ? null : _toggleRecording,
                      icon: Icon(_recording ? Icons.stop_circle_rounded : Icons.mic_rounded),
                      label: Text(_recording ? 'إيقاف التسجيل' : 'ابدأ التسجيل'),
                    ),
                    SwitchListTile(
                      value: _anonymous,
                      onChanged: (value) => setState(() => _anonymous = value),
                      activeColor: Colors.white,
                      title: const Text('النشر مجهول الهوية', style: TextStyle(color: Colors.white)),
                    ),
                    if (_recordPath != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _publishing ? null : _publish,
                          icon: const Icon(Icons.send_rounded),
                          label: Text(_publishing ? 'جارٍ النشر...' : 'نشر المقطع'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_posts.isEmpty)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('لا توجد مقاطع في دورة اليوم بعد.')))
              else
                ..._posts.map((post) {
                  final anonymous = post['is_anonymous'] == true;
                  final name = anonymous ? 'زميل مجهول' : (post['author_name']?.toString() ?? 'زميل');
                  final image = anonymous ? null : post['author_image']?.toString();
                  final pendingReview = post['moderation_status'] == 'pending_review';
                  final isAdmin = post['is_admin'] == true;
                  final canDelete = post['can_delete'] == true;
                  final liked = post['liked'] == true;
                  final likeCount = (post['like_count'] as num?)?.toInt() ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          if (pendingReview)
                            const ListTile(
                              dense: true,
                              leading: Icon(Icons.shield_outlined, color: Colors.orange),
                              title: Text('مخفي مؤقتًا بعد بلاغين وينتظر مراجعة الإدارة'),
                            ),
                          ListTile(
                            leading: CircleAvatar(backgroundImage: image != null && image.isNotEmpty ? NetworkImage(image) : null, child: image == null || image.isEmpty ? const Icon(Icons.graphic_eq_rounded) : null),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('مدة المقطع ${_duration((post['duration_seconds'] as num?)?.toInt() ?? 0)}'),
                            onTap: pendingReview ? null : () => _play(post),
                            trailing: IconButton(
                              onPressed: pendingReview ? null : () => _play(post),
                              icon: _loadingPlayId == post['id'].toString()
                                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(_playingId == post['id'].toString() ? Icons.stop_rounded : Icons.play_arrow_rounded),
                            ),
                          ),
                          ButtonBar(
                            alignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                onPressed: pendingReview ? null : () => _toggleLike(post),
                                icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? Colors.red : null),
                                label: Text('$likeCount'),
                              ),
                              if (!pendingReview && !canDelete)
                                TextButton.icon(onPressed: () => _report(post), icon: const Icon(Icons.flag_outlined), label: const Text('إبلاغ')),
                              if (canDelete)
                                TextButton.icon(onPressed: () => _deletePost(post), icon: const Icon(Icons.delete_outline), label: const Text('حذف')),
                              if (isAdmin && pendingReview) ...[
                                TextButton(onPressed: () => _reviewPost(post, true), child: const Text('إعادة')),
                                TextButton(onPressed: () => _reviewPost(post, false), child: const Text('حذف نهائي')),
                              ],
                              if (isAdmin)
                                IconButton(onPressed: () => _adminMute(post), tooltip: 'كتم إداري لأسبوع', icon: const Icon(Icons.volume_off_outlined)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
