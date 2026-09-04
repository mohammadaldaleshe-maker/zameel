import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../main.dart';
import '../books/books_screen.dart';
import '../groups/groups_screen.dart';
import '../saved_posts_screen.dart';
import '../stats_screen.dart';
import '../graduation/graduation_screen.dart';
import '../social/zameel_social_studio.dart';
import '../business/business_screen.dart';
import '../comments/comments_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _university = TextEditingController();
  final _college = TextEditingController();
  final _department = TextEditingController();

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _editing = false;
  bool _following = false;
  int _followers = 0;
  int _followingCount = 0;
  int _saved = 0;
  int _clips = 0;
  int _likesReceived = 0;
  int _comments = 0;
  bool _likedStateLoaded = false;
  Uint8List? _pendingAvatarBytes;
  Uint8List? _pendingCoverBytes;
  String? _pendingAvatarExt;
  String? _pendingCoverExt;

  bool get isMe => widget.userId == null ||
      widget.userId == Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _headline.dispose();
    _bio.dispose();
    _university.dispose();
    _college.dispose();
    _department.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final db = Supabase.instance.client;
      final authUser = db.auth.currentUser;
      final id = widget.userId ?? authUser?.id;
      if (id == null) return;

      final row = await db.from('users').select('*').eq('id', id).maybeSingle();
      final profileRow = await db.from('profiles').select('*').eq('id', id).maybeSingle();
      if (row == null && profileRow == null) {
        if (mounted) setState(() => _profile = null);
        return;
      }
      final profile = <String, dynamic>{
        if (row != null) ...Map<String, dynamic>.from(row),
        if (profileRow != null) ...Map<String, dynamic>.from(profileRow),
      };
      // Keep the legacy users keys used by existing widgets while preferring
      // the richer profiles record when both tables contain the same field.
      if (profile['name'] == null && profile['full_name'] != null) {
        profile['name'] = profile['full_name'];
      }
      if (profile['profile_image'] == null && profile['avatar_url'] != null) {
        profile['profile_image'] = profile['avatar_url'];
      }

      final posts = await db
          .from('posts')
          .select('*, users(name, profile_image)')
          .eq('user_id', id)
          .order('created_at', ascending: false);

      int followers = 0;
      int following = 0;
      int saved = 0;
      int clips = 0;
      bool followingMe = false;
      int likes = 0;
      int comments = 0;

      try {
        followers = (await db.from('follows').select('follower_id').eq('following_id', id)).length;
        following = (await db.from('follows').select('following_id').eq('follower_id', id)).length;
        if (isMe && authUser != null) {
          saved = (await db.from('saved_posts').select('post_id').eq('user_id', authUser.id)).length;
        }
        clips = (await db.from('clips').select('id').eq('user_id', id)).length;
        likes = (posts as List).fold<int>(0, (sum, p) => sum + ((p['likes_count'] ?? 0) as num).toInt());
        comments = (posts as List).fold<int>(0, (sum, p) => sum + ((p['comments_count'] ?? 0) as num).toInt());
        if (!isMe && authUser != null) {
          followingMe = await db
              .from('follows')
              .select('follower_id')
              .eq('follower_id', authUser.id)
              .eq('following_id', id)
              .maybeSingle() != null;
        }
      } catch (_) {
        // Optional social tables may not be migrated yet; profile still works.
      }

      profile['posts_count'] = (posts as List).length;
      profile['followers_count'] = followers;
      profile['following_count'] = following;
      profile['saved_count'] = saved;
      profile['clips_count'] = clips;
      profile['likes_received'] = likes;
      profile['comments_count_total'] = comments;

      if (mounted) {
        setState(() {
          _likedStateLoaded = false;
          _profile = profile;
          _posts = List<Map<String, dynamic>>.from(posts);
          _followers = followers;
          _followingCount = following;
          _saved = saved;
          _clips = clips;
          _likesReceived = likes;
          _comments = comments;
          _following = followingMe;
        });
      }
      _fillControllers(profile);
    } catch (e) {
      debugPrint('Profile load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillControllers(Map<String, dynamic> p) {
    _name.text = p['name']?.toString() ?? '';
    _username.text = p['username']?.toString() ?? '';
    _headline.text = p['headline']?.toString() ?? '';
    _bio.text = p['bio']?.toString() ?? '';
    _university.text = p['university']?.toString() ?? '';
    _college.text = p['college']?.toString() ?? '';
    _department.text = p['department']?.toString() ?? '';
  }

  Future<void> _saveProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final name = _name.text.trim().isEmpty ? 'مستخدم' : _name.text.trim();
      final username = _username.text.trim().isEmpty ? null : _username.text.trim().toLowerCase();
      final bio = _bio.text.trim();
      final db = Supabase.instance.client;
      final now = DateTime.now().toIso8601String();
      String? avatarUrl = _profile?['profile_image']?.toString();
      String? coverUrl = _profile?['cover_image']?.toString();

      Future<String> uploadProfileImage(Uint8List bytes, String ext, String kind) async {
        final safeExt = ext.isEmpty ? 'jpg' : ext;
        final path = '${user.id}/${kind}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
        final contentType = safeExt == 'png' ? 'image/png' : (safeExt == 'webp' ? 'image/webp' : 'image/jpeg');
        await db.storage.from('profiles').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
        return db.storage.from('profiles').getPublicUrl(path);
      }

      if (_pendingAvatarBytes != null) {
        avatarUrl = await uploadProfileImage(_pendingAvatarBytes!, _pendingAvatarExt ?? 'jpg', 'profile');
      }
      if (_pendingCoverBytes != null) {
        coverUrl = await uploadProfileImage(_pendingCoverBytes!, _pendingCoverExt ?? 'jpg', 'cover');
      }

      await db.from('users').update({
        'name': name,
        'username': username,
        'headline': _headline.text.trim(),
        'bio': bio,
        'university': _university.text.trim(),
        'college': _college.text.trim(),
        'department': _department.text.trim(),
        'profile_image': avatarUrl,
        'cover_image': coverUrl,
        'profile_completed_at': now,
        'updated_at': now,
      }).eq('id', user.id);
      await db.from('profiles').upsert({
        'id': user.id,
        'full_name': name,
        'username': username,
        'bio': bio,
        'avatar_url': avatarUrl,
        'cover_image': coverUrl,
        'headline': _headline.text.trim(),
        'email': user.email,
        'updated_at': now,
      });
      if (!mounted) return;
      setState(() {
        _editing = false;
        _profile = {...?_profile,
          'name': _name.text.trim(), 'username': _username.text.trim(),
          'headline': _headline.text.trim(), 'bio': _bio.text.trim(),
          'university': _university.text.trim(), 'college': _college.text.trim(),
          'department': _department.text.trim(),
          'profile_image': avatarUrl,
          'cover_image': coverUrl,
        };
        _pendingAvatarBytes = null;
        _pendingCoverBytes = null;
        _pendingAvatarExt = null;
        _pendingCoverExt = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الملف الشخصي بنجاح ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ التعديلات: $e')));
    }
  }

  Future<void> _pickImage({required bool cover}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || !isMe) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(Provider.of<LanguageProvider>(context, listen: false).isArabic ? 'اختيار من المعرض' : 'Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(Provider.of<LanguageProvider>(context, listen: false).isArabic ? 'فتح الكاميرا' : 'Open camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final image = await _picker.pickImage(source: source, imageQuality: 88);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final ext = image.name.contains('.') ? image.name.split('.').last.toLowerCase() : 'jpg';
      if (!mounted) return;
      setState(() {
        _editing = true;
        if (cover) {
          _pendingCoverBytes = bytes;
          _pendingCoverExt = ext;
        } else {
          _pendingAvatarBytes = bytes;
          _pendingAvatarExt = ext;
        }
        _profile = {...?_profile, cover ? 'cover_image' : 'profile_image': null};
      });
      showMessage(Provider.of<LanguageProvider>(context, listen: false).isArabic
          ? 'تم اختيار الصورة. اضغط «حفظ التغييرات» لتثبيتها.'
          : 'Image selected. Press “Save changes” to apply it.');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر اختيار الصورة: $e')));
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleFollow() async {
    final me = Supabase.instance.client.auth.currentUser;
    final target = widget.userId;
    if (me == null || target == null || me.id == target) return;
    final db = Supabase.instance.client;
    try {
      if (_following) {
        await db.from('follows').delete().eq('follower_id', me.id).eq('following_id', target);
        if (mounted) setState(() { _following = false; _followers = _followers > 0 ? _followers - 1 : 0; });
      } else {
        await db.from('follows').upsert({'follower_id': me.id, 'following_id': target});
        if (mounted) setState(() { _following = true; _followers++; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث المتابعة: $e')));
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final me = Supabase.instance.client.auth.currentUser;
    final id = post['id'];
    if (me == null || id == null) return;
    final liked = post['liked'] == true;
    final oldCount = ((post['likes_count'] ?? 0) as num).toInt();
    setState(() {
      post['liked'] = !liked;
      post['likes_count'] = liked ? (oldCount > 0 ? oldCount - 1 : 0) : oldCount + 1;
    });
    try {
      if (liked) {
        await Supabase.instance.client.from('likes').delete().eq('user_id', me.id).eq('post_id', id);
      } else {
        await Supabase.instance.client.from('likes').upsert({'user_id': me.id, 'post_id': id});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { post['liked'] = liked; post['likes_count'] = oldCount; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل الإعجاب: $e')));
    }
  }

  Future<void> _prepareLikedState() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null || _posts.isEmpty) return;
    try {
      final rows = await Supabase.instance.client.from('likes').select('post_id').eq('user_id', me.id);
      final ids = rows.map<String>((r) => r['post_id'].toString()).toSet();
      if (!mounted) return;
      setState(() {
        _likedStateLoaded = true;
        for (final p in _posts) {
          p['liked'] = ids.contains(p['id'].toString());
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    if (!_loading && _profile != null && _posts.isNotEmpty && !_likedStateLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_likedStateLoaded) _prepareLikedState();
      });
    }

    if (_loading) return const _ProfileLoading();
    if (_profile == null) return _NotFound(ar: ar);

    final p = _profile!;
    final name = p['name']?.toString().trim().isNotEmpty == true ? p['name'] : (ar ? 'طالب زميل' : 'Zameel Student');
    final image = p['profile_image']?.toString();
    final cover = p['cover_image']?.toString();
    final username = p['username']?.toString();
    final headline = p['headline']?.toString() ?? '';
    final bio = p['bio']?.toString() ?? '';
    final role = p['role']?.toString() ?? 'student';

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          title: Text(isMe ? (ar ? 'ملفي في زميل' : 'My Zameel Profile') : name),
          actions: [
            if (isMe) IconButton(icon: Icon(_editing ? Icons.close_rounded : Icons.edit_rounded), onPressed: () => setState(() => _editing = !_editing)),
            if (!isMe) IconButton(icon: const Icon(Icons.more_horiz_rounded), onPressed: _showMore),
          ],
        ),
        bottomNavigationBar: isMe && _editing
            ? SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 10), child: FilledButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save_rounded), label: Text(ar ? 'حفظ الصورة والتغييرات' : 'Save photo & changes'))))
            : null,
        body: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHero(ar, name, image, cover, username, headline, bio, role)),
              SliverToBoxAdapter(child: _buildQuickDashboard(ar)),
              if (_editing && isMe) SliverToBoxAdapter(child: _buildEditCard(ar)),
              SliverToBoxAdapter(child: _buildSectionHeader(ar)),
              if (_posts.isEmpty)
                SliverToBoxAdapter(child: _emptyPosts(ar))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
                  sliver: SliverList.separated(
                    itemCount: _posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _postCard(_posts[i], ar),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(bool ar, dynamic name, String? image, String? cover, String? username, String headline, String bio, String role) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6A2CCB), Color(0xFF174BE8)]),
                image: _pendingCoverBytes != null ? DecorationImage(image: MemoryImage(_pendingCoverBytes!), fit: BoxFit.cover) : (cover != null && cover.isNotEmpty ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover) : null),
              ),
            ),
            Positioned(
              left: 18, right: 18, bottom: -54,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: isMe ? () => _pickImage(cover: false) : null,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: const Color(0xFFE7E7F3),
                        backgroundImage: _pendingAvatarBytes != null ? MemoryImage(_pendingAvatarBytes!) : (image != null && image.isNotEmpty ? NetworkImage(image) : null),
                        child: image == null || image.isEmpty ? Image.asset('assets/branding/zameel_mark.png', width: 70, height: 70) : null,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!isMe)
                    FilledButton.icon(
                      onPressed: _toggleFollow,
                      icon: Icon(_following ? Icons.check_rounded : Icons.person_add_alt_1_rounded),
                      label: Text(_following ? (ar ? 'تتابعه' : 'Following') : (ar ? 'متابعة' : 'Follow')),
                    )
                  else
                    OutlinedButton.icon(onPressed: () => setState(() => _editing = true), icon: const Icon(Icons.edit_rounded), label: Text(ar ? 'تعديل الملف' : 'Edit profile')),
                ],
              ),
            ),
            if (isMe)
              Positioned(
                top: 12, left: 12,
                child: IconButton.filledTonal(
                  onPressed: () => _pickImage(cover: true),
                  icon: const Icon(Icons.photo_camera_rounded),
                  tooltip: ar ? 'تغيير الغلاف' : 'Change cover',
                ),
              ),
          ],
        ),
        const SizedBox(height: 66),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: Text('$name', textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800))),
                if (role == 'student') ...[const SizedBox(width: 6), const Icon(Icons.verified_rounded, color: Color(0xFF3B82F6), size: 20)],
              ]),
              if (username != null && username.isNotEmpty) Text('@$username', style: const TextStyle(color: Colors.grey)),
              if (headline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(headline, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4B5563)))),
              if (bio.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF667085), height: 1.45))),
              if ((pString('university')).isNotEmpty || pString('college').isNotEmpty || pString('department').isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
                  if (pString('university').isNotEmpty) _chip(Icons.account_balance_rounded, pString('university')),
                  if (pString('college').isNotEmpty) _chip(Icons.school_rounded, pString('college')),
                  if (pString('department').isNotEmpty) _chip(Icons.menu_book_rounded, pString('department')),
                ])),
            ],
          ),
        ),
      ],
    );
  }

  String pString(String key) => _profile?[key]?.toString() ?? '';

  Widget _chip(IconData icon, String text) => Chip(avatar: Icon(icon, size: 15), label: Text(text), visualDensity: VisualDensity.compact);

  Widget _buildQuickDashboard(bool ar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _metric(ar ? 'منشورات' : 'Posts', '${_posts.length}', Icons.article_outlined),
              _metric(ar ? 'متابعون' : 'Followers', '$_followers', Icons.people_alt_outlined),
              _metric(ar ? 'يتابع' : 'Following', '$_followingCount', Icons.person_outline_rounded),
              _metric(ar ? 'إعجابات' : 'Likes', '$_likesReceived', Icons.favorite_border_rounded),
            ]),
            const Divider(height: 22),
            SizedBox(
              height: 74,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _shortcut(Icons.insights_rounded, ar ? 'إحصاءاتي' : 'Insights', _openStats),
                  _shortcut(Icons.timeline_rounded, ar ? 'نشاطي' : 'Activity', _openActivity),
                  _shortcut(Icons.emoji_events_rounded, ar ? 'إنجازاتي' : 'Achievements', _openAchievements),
                  _shortcut(Icons.bookmark_rounded, ar ? 'المحفوظات' : 'Saved', _openSaved),
                  _shortcut(Icons.menu_book_rounded, ar ? 'كتبي وملفاتي' : 'Books', _openBooks),
                  _shortcut(Icons.groups_rounded, ar ? 'مجموعاتي' : 'Groups', _openGroups),
                  _shortcut(Icons.auto_awesome_rounded, ar ? 'مجتمع الزملاء' : 'Community', _openSocial),
                  _shortcut(Icons.business_center_rounded, ar ? 'شركاء زميل' : 'Zameel Partners', _openBusiness),
                  _shortcut(Icons.school_rounded, ar ? 'كتاب الخريجين' : 'Alumni Book', _openGraduation),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Expanded(child: Column(children: [Icon(icon, size: 20, color: const Color(0xFF5B35C8)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))]));

  Widget _shortcut(IconData icon, String label, VoidCallback onTap) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: SizedBox(width: 72, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFF0ECFF), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFF5B35C8))), const SizedBox(height: 5), Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))]))));

  Widget _buildEditCard(bool ar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(ar ? 'تخصيص ملفك' : 'Customize your profile', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _field(_name, ar ? 'الاسم الكامل' : 'Full name', Icons.person_outline_rounded),
            _field(_username, ar ? 'اسم المستخدم' : 'Username', Icons.alternate_email_rounded),
            _field(_headline, ar ? 'العنوان المختصر' : 'Headline', Icons.badge_outlined),
            _field(_bio, ar ? 'نبذة عنك' : 'Bio', Icons.notes_rounded, maxLines: 3),
            _field(_university, ar ? 'الجامعة' : 'University', Icons.account_balance_rounded),
            _field(_college, ar ? 'الكلية' : 'College', Icons.school_outlined),
            _field(_department, ar ? 'التخصص / القسم' : 'Major / Department', Icons.menu_book_outlined),
            const SizedBox(height: 4),
            FilledButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save_rounded), label: Text(ar ? 'حفظ التغييرات' : 'Save changes')),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {int maxLines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 9), child: TextField(controller: c, maxLines: maxLines, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), filled: true)));

  Widget _buildSectionHeader(bool ar) => Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 10), child: Row(children: [Text(ar ? 'منشوراتي' : 'My posts', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), const Spacer(), Text('${_posts.length}', style: const TextStyle(color: Colors.grey))]));

  Widget _emptyPosts(bool ar) => Padding(padding: const EdgeInsets.all(40), child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Image.asset('assets/branding/zameel_mark.png', width: 70, height: 70), const SizedBox(height: 12), Text(ar ? 'لم تنشر شيئًا بعد' : 'No posts yet', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(ar ? 'ابدأ بمشاركة شيء مفيد مع زملائك.' : 'Share something useful with your classmates.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))]))));

  Widget _postCard(Map<String, dynamic> post, bool ar) {
    final text = (ar ? post['text_ar'] : post['text_en'])?.toString() ?? '';
    final liked = post['liked'] == true;
    final image = post['image_url']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 20, child: Icon(Icons.person)),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_profile?['name']?.toString() ?? (ar ? 'طالب زميل' : 'Zameel Student'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(_profile?['university']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded, color: Colors.grey),
              ],
            ),
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(text, style: const TextStyle(fontSize: 15, height: 1.55)),
              ),
            if (image != null && image.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    image,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 120,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 16, color: liked ? Colors.pink : Colors.grey),
                const SizedBox(width: 5),
                Text('${post['likes_count'] ?? 0}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(width: 15),
                const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text('${post['comments_count'] ?? 0}', style: const TextStyle(color: Colors.grey)),
                const Spacer(),
                Text(_formatDate(post['created_at']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(child: _postAction(Icons.favorite_border_rounded, ar ? 'إعجاب' : 'Like', liked, () => _toggleLike(post))),
                Expanded(child: _postAction(Icons.chat_bubble_outline_rounded, ar ? 'تعليق' : 'Comment', false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsScreen(post: post))))),
                Expanded(child: _postAction(Icons.bookmark_border_rounded, ar ? 'حفظ' : 'Save', false, () => _save(post))),
                Expanded(child: _postAction(Icons.share_outlined, ar ? 'مشاركة' : 'Share', false, () => _share(post))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _postAction(IconData icon, String label, bool active, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(children: [Icon(active ? Icons.favorite_rounded : icon, size: 20, color: active ? Colors.pink : Colors.grey.shade700), const SizedBox(height: 3), Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.pink : Colors.grey.shade700))])));

  Future<void> _save(Map<String, dynamic> post) async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null || post['id'] == null) return;
    try { await Supabase.instance.client.from('saved_posts').upsert({'user_id': me.id, 'post_id': post['id']}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المنشور ✓'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e'))); }
  }

  Future<void> _share(Map<String, dynamic> post) async {
    final text = (post['text_ar'] ?? post['text_en'] ?? '').toString();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ محتوى المنشور للمشاركة ✓')));
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    try { final d = DateTime.parse(value.toString()); final diff = DateTime.now().difference(d); if (diff.inMinutes < 1) return 'الآن'; if (diff.inHours < 1) return 'منذ ${diff.inMinutes} د'; if (diff.inDays < 1) return 'منذ ${diff.inHours} س'; return 'منذ ${diff.inDays} ي'; } catch (_) { return ''; }
  }

  void _openActivity() => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileActivityScreen(posts: _posts, ar: Provider.of<LanguageProvider>(context, listen: false).isArabic)));
  void _openAchievements() => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileAchievementsScreen(posts: _posts.length, likes: _likesReceived, followers: _followers, clips: _clips, ar: Provider.of<LanguageProvider>(context, listen: false).isArabic)));
  void _openStats() => Navigator.push(context, MaterialPageRoute(builder: (_) => StatsScreen(postsCount: _posts.length, likesCount: _likesReceived, commentsCount: _comments, friendsCount: _followers, savedBooksCount: _saved, activeDays: 0)));
  Future<void> _openSaved() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('saved_posts')
          .select('posts(*, users(name, profile_image))')
          .eq('user_id', me.id)
          .order('created_at', ascending: false);
      final saved = <Map<String, dynamic>>[];
      for (final row in rows) {
        final post = row['posts'];
        if (post is Map<String, dynamic>) saved.add({...post, 'isSaved': true});
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => SavedPostsScreen(savedPosts: saved)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح المحفوظات: $e')));
    }
  }
  void _openBooks() => Navigator.push(context, MaterialPageRoute(builder: (_) => const BooksScreen()));
  void _openGroups() => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsScreen()));
  void _openSocial() => Navigator.push(context, MaterialPageRoute(builder: (_) => ZameelSocialStudio(isArabic: Provider.of<LanguageProvider>(context, listen: false).isArabic)));
  void _openBusiness() => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessScreen()));
  void _openGraduation() => Navigator.push(context, MaterialPageRoute(builder: (_) => GraduationBookScreen(studentName: pString('name').isEmpty ? 'طالب زميل' : pString('name'), university: pString('university'), major: pString('department'), graduationYear: '2026')));

  void _showMore() {
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.share_rounded), title: Text(ar ? 'مشاركة الملف' : 'Share profile'), onTap: () { Navigator.pop(context); Clipboard.setData(ClipboardData(text: pString('name'))); }), ListTile(leading: const Icon(Icons.block_rounded, color: Colors.red), title: Text(ar ? 'حظر المستخدم' : 'Block user'), onTap: () => Navigator.pop(context))])));
  }
}


class ProfileActivityScreen extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool ar;
  const ProfileActivityScreen({super.key, required this.posts, required this.ar});

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, dynamic>>[];
    for (final post in posts.take(20)) {
      items.add({
        'icon': post['type'] == 'image' ? Icons.photo_rounded : Icons.article_rounded,
        'title': ar ? 'نشرت منشورًا جديدًا' : 'Published a new post',
        'subtitle': (ar ? post['text_ar'] : post['text_en'])?.toString() ?? '',
      });
    }
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'نشاطي' : 'My Activity')),
        backgroundColor: const Color(0xFFF6F7FB),
        body: items.isEmpty
            ? Center(child: Text(ar ? 'لا يوجد نشاط بعد.' : 'No activity yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFF0ECFF), child: Icon(items[i]['icon'], color: const Color(0xFF5B21B6))), title: Text(items[i]['title'], style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(items[i]['subtitle'], maxLines: 2, overflow: TextOverflow.ellipsis))),
              ),
      ),
    );
  }
}

class ProfileAchievementsScreen extends StatelessWidget {
  final int posts;
  final int likes;
  final int followers;
  final int clips;
  final bool ar;
  const ProfileAchievementsScreen({super.key, required this.posts, required this.likes, required this.followers, required this.clips, required this.ar});

  @override
  Widget build(BuildContext context) {
    final achievements = [
      (ar ? 'أول منشور' : 'First post', ar ? 'انضممت إلى مجتمع زميل وشاركت أول منشور.' : 'You shared your first Zameel post.', posts >= 1, Icons.edit_note_rounded),
      (ar ? 'صوت المجتمع' : 'Community voice', ar ? 'حصلت منشوراتك على 10 إعجابات.' : 'Your posts received 10 likes.', likes >= 10, Icons.favorite_rounded),
      (ar ? 'زميل مؤثر' : 'Community builder', ar ? 'وصلت إلى 25 متابعًا.' : 'You reached 25 followers.', followers >= 25, Icons.people_alt_rounded),
      (ar ? 'صانع المقاطع' : 'Clip creator', ar ? 'أنشأت أول مقطع في مجتمع الزملاء.' : 'You created your first community clip.', clips >= 1, Icons.movie_creation_rounded),
    ];
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'إنجازاتي' : 'Achievements')),
        backgroundColor: const Color(0xFFF6F7FB),
        body: ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: achievements.length,
          separatorBuilder: (_, __) => const SizedBox(height: 9),
          itemBuilder: (_, i) {
            final a = achievements[i];
            final unlocked = a.$3 as bool;
            return Card(child: ListTile(leading: CircleAvatar(backgroundColor: unlocked ? const Color(0xFFEDE9FE) : const Color(0xFFF2F4F7), child: Icon(a.$4 as IconData, color: unlocked ? const Color(0xFF5B21B6) : Colors.grey)), title: Text(a.$1 as String, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(a.$2 as String), trailing: Icon(unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded, color: unlocked ? Colors.green : Colors.grey)));
          },
        ),
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _NotFound extends StatelessWidget {
  final bool ar;
  const _NotFound({required this.ar});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(), body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Image.asset('assets/branding/zameel_mark.png', width: 80, height: 80), const SizedBox(height: 12), Text(ar ? 'المستخدم غير موجود' : 'User not found', style: const TextStyle(fontWeight: FontWeight.bold))])));
}
