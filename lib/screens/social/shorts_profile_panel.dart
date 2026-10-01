import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/cached_media_image.dart';
import 'public_clips_strip.dart';
import 'clip_create_screen.dart';
class ShortsProfilePanel extends StatefulWidget {
  const ShortsProfilePanel({super.key, required this.userId, required this.ar, this.savedOnly = false});
  final String userId;
  final bool ar;
  final bool savedOnly;
  @override
  State<ShortsProfilePanel> createState() => _ShortsProfilePanelState();
}
class _ShortsProfilePanelState extends State<ShortsProfilePanel> {
  late Future<List<Map<String, dynamic>>> _rows;
  bool _loadingMore = false;
  bool _hasMore = true;
  @override
  void initState() { super.initState(); _rows = _load(); }
  Future<List<Map<String, dynamic>>> _load() async {
    final actor = Supabase.instance.client.auth.currentUser?.id;
    final data = await Supabase.instance.client.rpc('zameel_shorts_feed', params: {'p_author': widget.savedOnly ? null : widget.userId, 'p_saved': widget.savedOnly});
    if (actor != Supabase.instance.client.auth.currentUser?.id) throw StateError('session_changed');
    return (data as List).whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList();
  }
  Future<void> _more() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final rows = await _rows;
      final raw = await Supabase.instance.client.rpc('zameel_shorts_feed', params: {'p_author': widget.savedOnly ? null : widget.userId, 'p_saved': widget.savedOnly, 'p_offset': rows.length});
      final next = (raw as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
      final ids = rows.map((row) => row['id'].toString()).toSet();
      if (mounted) setState(() { _rows = Future.value([...rows, ...next.where((row) => !ids.contains(row['id'].toString()))]); _hasMore = next.length == 60; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.ar ? 'تعذر تحميل المزيد' : 'Could not load more')));
    } finally { if (mounted) setState(() => _loadingMore = false); }
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    if (Supabase.instance.client.auth.currentUser?.id == widget.userId && !widget.savedOnly) TextButton.icon(icon: const Icon(Icons.add), label: Text(widget.ar ? 'نشر شورتس' : 'Publish a Short'), onPressed: () async {
      await Navigator.push(context, MaterialPageRoute<bool>(builder: (_) => ClipCreateScreen(isArabic: widget.ar)));
      if (mounted) setState(() => _rows = _load());
    }),
    FutureBuilder<List<Map<String, dynamic>>>(future: _rows, builder: (context, snapshot) {
      if (snapshot.hasError) return TextButton(onPressed: () => setState(() => _rows = _load()), child: Text(widget.ar ? 'إعادة المحاولة' : 'Retry'));
      if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator());
      final rows = snapshot.data!;
      if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Text(widget.ar ? 'لا توجد شورتس متاحة' : 'No Shorts available'));
      return Column(children: [GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.all(14), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: .7, crossAxisSpacing: 6, mainAxisSpacing: 6), itemCount: rows.length, itemBuilder: (context, index) {
        final cover = rows[index]['cover_url']?.toString() ?? '';
        return GestureDetector(onTap: () async { await openShortsViewer(context, rows, index, authorId: widget.savedOnly ? null : widget.userId, savedOnly: widget.savedOnly); if (mounted) setState(() { _hasMore = true; _rows = _load(); }); }, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: cover.isEmpty ? const ColoredBox(color: Colors.teal) : CachedMediaImage(url: cover, fit: BoxFit.cover, cacheWidth: 320, fallback: const ColoredBox(color: Colors.teal))));
      }), if (_hasMore && rows.length >= 60) TextButton(onPressed: _loadingMore ? null : _more, child: Text(widget.ar ? 'عرض المزيد' : 'Load more'))]);
    }),
  ]);
}
