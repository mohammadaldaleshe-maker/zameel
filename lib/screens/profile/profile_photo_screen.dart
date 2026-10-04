import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../../services/feature_control.dart';

/// Dedicated image interactions: there is no post or promotion action here.
class ProfilePhotoScreen extends StatefulWidget {
  final String ownerId, kind, imageUrl;
  const ProfilePhotoScreen(
      {super.key,
      required this.ownerId,
      required this.kind,
      required this.imageUrl});
  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  final _text = TextEditingController();
  String? _photoId, _error;
  bool _loading = true,
      _busy = false,
      _liked = false,
      _more = false,
      _paging = false;
  int _likes = 0;
  List<Map<String, dynamic>> _comments = [];
  SupabaseClient get db => Supabase.instance.client;
  bool get ar => context.read<LanguageProvider>().isArabic;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = db.auth.currentUser?.id;
    try {
      final state = Map<String, dynamic>.from(await db
          .rpc('zameel_open_profile_photo', params: {
        'p_owner': widget.ownerId,
        'p_kind': widget.kind,
        'p_url': widget.imageUrl
      }).timeout(const Duration(seconds: 15)));
      if (!mounted || db.auth.currentUser?.id != session) return;
      setState(() {
        _photoId = state['id'].toString();
        _likes = (state['likes'] as num).toInt();
        _liked = state['liked'] == true;
        _error = null;
        _loading = false;
      });
      await _loadComments(reset: true);
    } catch (e) {
      if (e is PostgrestException && e.message.contains('profile_photo_unavailable')) _photoId = null;
      if (mounted)
        setState(() {
          _loading = false;
          _error = ar
              ? 'تعذر تحميل التفاعلات. أعد المحاولة.'
              : 'Unable to load reactions. Try again.';
        });
    }
  }

  Future<void> _loadComments({bool reset = false}) async {
    if (_photoId == null || _paging) return;
    _paging = true;
    try {
      final offset = reset ? 0 : _comments.length;
      final rows = await db
          .from('zameel_profile_photo_comments')
          .select('id,user_id,content,created_at,users(name,profile_image)')
          .eq('photo_id', _photoId!)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + 29)
          .timeout(const Duration(seconds: 15));
      if (mounted)
        setState(() {
          if (reset)
            _comments = List<Map<String, dynamic>>.from(rows);
          else
            _comments.addAll(List<Map<String, dynamic>>.from(rows));
          _more = rows.length == 30;
        });
    } finally {
      _paging = false;
      if (mounted) setState(() {});
    }
  }

  void _failure() {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar
              ? 'تعذر حفظ التفاعل. أعد المحاولة.'
              : 'Unable to save. Try again.')));
  }

  Future<void> _like() async {
    if (_busy || _photoId == null) return;
    setState(() => _busy = true);
    try {
      final state = Map<String, dynamic>.from(await db.rpc(
          'zameel_toggle_profile_photo_like',
          params: {'p_photo': _photoId}));
      if (mounted)
        setState(() {
          _liked = state['liked'] == true;
          _likes = (state['likes'] as num).toInt();
        });
    } catch (_) {
      _failure();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _comment() async {
    if (_busy || _photoId == null || _text.text.trim().isEmpty) return;
    if (!await FeatureControl.instance.check(context, 'comments') || !mounted)
      return;
    setState(() => _busy = true);
    try {
      await db.rpc('zameel_comment_profile_photo',
          params: {'p_photo': _photoId, 'p_content': _text.text.trim()});
      _text.clear();
      await _loadComments(reset: true);
    } catch (_) {
      _failure();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final arabic = context.watch<LanguageProvider>().isArabic;
    return Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
              title: Text(widget.kind == 'cover'
                  ? (arabic ? 'صورة الغلاف' : 'Cover photo')
                  : (arabic ? 'الصورة الشخصية' : 'Profile photo'))),
          body: CustomScrollView(slivers: [
            SliverToBoxAdapter(
                child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .45,
                    child: ColoredBox(
                        color: Colors.black,
                        child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 5,
                            child: Center(
                                child: _photoId == null
                                    ? const Icon(Icons.image_outlined,
                                        color: Colors.white)
                                    : Image.network(widget.imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image,
                                                color: Colors.white))))))),
            if (_loading)
              const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator())))
            else if (_error != null)
              SliverToBoxAdapter(
                  child: Column(children: [
                Text(_error!),
                TextButton(
                    onPressed: _load,
                    child: Text(arabic ? 'إعادة المحاولة' : 'Retry'))
              ]))
            else ...[
              SliverToBoxAdapter(
                  child: Row(children: [
                TextButton.icon(
                    onPressed: _busy ? null : _like,
                    icon: Icon(_liked ? Icons.favorite : Icons.favorite_border),
                    label: Text('$_likes ${arabic ? 'إعجاب' : 'likes'}'))
              ])),
              SliverList.builder(
                  itemCount: _comments.length,
                  itemBuilder: (_, i) {
                    final c = _comments[i];
                    final user = c['users'];
                    return ListTile(
                        title: Text(user is Map
                            ? user['name']?.toString() ??
                                (arabic ? 'زميل' : 'User')
                            : (arabic ? 'زميل' : 'User')),
                        subtitle: Text(c['content'].toString()));
                  }),
              if (_more)
                SliverToBoxAdapter(
                    child: TextButton(
                        onPressed: _paging
                            ? null
                            : () async {
                                try {
                                  await _loadComments();
                                } catch (_) {
                                  _failure();
                                }
                              },
                        child: Text(arabic ? 'عرض المزيد' : 'Load more'))),
            ],
          ]),
          bottomNavigationBar:
              _photoId != null && FeatureControl.instance.visible('comments')
                  ? SafeArea(
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(children: [
                            Expanded(
                                child: TextField(
                                    controller: _text,
                                    maxLength: 2000,
                                    minLines: 1,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                        hintText: arabic
                                            ? 'اكتب تعليقًا…'
                                            : 'Write a comment…',
                                        counterText: ''))),
                            IconButton(
                                onPressed: _busy ? null : _comment,
                                icon: const Icon(Icons.send))
                          ])))
                  : null,
        ));
  }
}
