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
import '../chat/chat_screen.dart';
import 'profile_settings_screen.dart';
import '../../theme/app_theme.dart';

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
  List<Map<String, dynamic>> _sharedPosts = [];
  bool _loading = true;
  bool _editing = false;
  bool _following = false;
  String _friendStatus = 'none';
  bool _blocked = false;
  int _followers = 0;
  int _followingCount = 0;
  int _saved = 0;
  int _clips = 0;
  int _likesReceived = 0;
  int _comments = 0;
  bool _likedStateLoaded = false;
  bool _bookExists = false;
  bool _bookVisible = true;

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
      if (row == null) {
        if (mounted) setState(() => _profile = null);
        return;
      }
      final profile = Map<String, dynamic>.from(row);

      try {
        final book = await db
            .from('graduation_books')
            .select('id,is_public')
            .eq('owner_id', id)
            .maybeSingle();
        _bookExists = book != null;
        _bookVisible = book == null || book['is_public'] != false;
      } catch (_) {
        _bookExists = false;
        _bookVisible = true;
      }

      final posts = await db
          .from('posts')
          .select('*, users(name, profile_image)')
          .eq('user_id', id)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> sharedPosts = [];
      try {
        final sharedRows = await db
            .from('shared_posts')
            .select('id, post_id, shared_by, created_at, posts(*, users(name, profile_image))')
            .eq('shared_by', id)
            .order('created_at', ascending: false);
        sharedPosts = List<Map<String, dynamic>>.from(sharedRows).map((row) {
          final original = row['posts'];
          if (original is Map) {
            return {
              ...Map<String, dynamic>.from(original),
              'shared_row_id': row['id'],
              'shared_by_me': true,
              'shared_at': row['created_at'],
            };
          }
          return <String, dynamic>{};
        }).where((p) => p.isNotEmpty).toList();
      } catch (_) {}

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
        if (!isMe && authUser != null) {
          final req = await db.from('friend_requests').select('id,sender_id,receiver_id,status').or('and(sender_id.eq.${authUser.id},receiver_id.eq.$id),and(sender_id.eq.$id,receiver_id.eq.${authUser.id})').order('created_at', ascending: false).limit(1);
          if (req.isNotEmpty) profile['friend_status'] = req.first['status'];
          final block = await db.from('user_blocks').select('id').eq('blocker_id', authUser.id).eq('blocked_id', id).maybeSingle();
          final blockedByTarget = await db.from('user_blocks').select('id').eq('blocker_id', id).eq('blocked_id', authUser.id).maybeSingle();
          profile['blocked'] = block != null;
          profile['blocked_by_target'] = blockedByTarget != null;
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
          _sharedPosts = sharedPosts;
          _followers = followers;
          _followingCount = following;
          _saved = saved;
          _clips = clips;
          _likesReceived = likes;
          _comments = comments;
          _following = followingMe;
          _friendStatus = profile['friend_status']?.toString() ?? 'none';
          _blocked = profile['blocked'] == true;
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
      await Supabase.instance.client.from('users').update({
        'name': _name.text.trim().isEmpty ? 'مستخدم' : _name.text.trim(),
        'username': _username.text.trim().isEmpty ? null : _username.text.trim().toLowerCase(),
        'headline': _headline.text.trim(),
        'bio': _bio.text.trim(),
        'university': _university.text.trim(),
        'college': _college.text.trim(),
        'department': _department.text.trim(),
        'profile_completed_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _profile = {...?_profile,
          'name': _name.text.trim(), 'username': _username.text.trim(),
          'headline': _headline.text.trim(), 'bio': _bio.text.trim(),
          'university': _university.text.trim(), 'college': _college.text.trim(),
          'department': _department.text.trim(),
        };
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('التقاط بالكاميرا'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: cover ? 1800 : 1200,
    );
    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      final rawExt = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';
      final ext = rawExt == 'jpg' || rawExt == 'jpeg' ? 'jpg' : rawExt;
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final path =
          '${user.id}/${cover ? 'cover' : 'profile'}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage.from('profiles').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      final url =
          '${Supabase.instance.client.storage.from('profiles').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client.from('users').update(
        {cover ? 'cover_image' : 'profile_image': url},
      ).eq('id', user.id);

      if (!mounted) return;
      setState(() {
        _profile = {
          ...?_profile,
          cover ? 'cover_image' : 'profile_image': url,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cover ? 'تم تحديث صورة الغلاف ✓' : 'تم تحديث الصورة الشخصية ✓'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر رفع الصورة: $e')),
        );
      }
    }
  }

  Future<void> _sendFriendRequest() async {
    final db = Supabase.instance.client;
    final me = db.auth.currentUser;
    final target = widget.userId;
    if (me == null || target == null || me.id == target) return;

    try {
      final existing = await db
          .from('friend_requests')
          .select('id,sender_id,receiver_id,status,created_at')
          .or('and(sender_id.eq.${me.id},receiver_id.eq.$target),and(sender_id.eq.$target,receiver_id.eq.${me.id})')
          .order('created_at', ascending: false)
          .limit(1);

      if (existing.isNotEmpty) {
        final current = Map<String, dynamic>.from(existing.first);
        final status = current['status']?.toString() ?? 'none';
        final senderId = current['sender_id']?.toString();

        if (status == 'accepted') {
          if (mounted) setState(() => _friendStatus = 'accepted');
          return;
        }

        if (status == 'pending') {
          if (senderId == me.id) {
            if (mounted) setState(() => _friendStatus = 'pending');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إرسال طلب الزمالة مسبقًا وهو بانتظار القبول.')),
              );
            }
          } else {
            if (mounted) setState(() => _friendStatus = 'incoming');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لدى هذا المستخدم طلب زمالة مرسل إليك. افتح قسم الزملاء لقبوله.')),
              );
            }
          }
          return;
        }
      }

      final targetRow = await db
          .from('users')
          .select('name')
          .eq('id', target)
          .maybeSingle();

      await db.from('friend_requests').insert({
        'sender_id': me.id,
        'receiver_id': target,
        'sender_name': me.userMetadata?['name']?.toString() ?? 'زميل',
        'receiver_name': targetRow?['name']?.toString() ?? 'زميل',
        'status': 'pending',
      });

      await db.from('notifications').insert({
        'user_id': target,
        'actor_id': me.id,
        'type': 'friend_request',
        'title_ar': 'طلب زميل جديد',
        'title_en': 'New colleague request',
        'body_ar': '${me.userMetadata?['name'] ?? 'زميل'} أرسل لك طلب زميل',
        'body_en': '${me.userMetadata?['name'] ?? 'Colleague'} sent you a colleague request',
        'data': {},
      });

      if (mounted) setState(() => _friendStatus = 'pending');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الزمالة ✓')),
        );
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        if (mounted) setState(() => _friendStatus = 'pending');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال طلب الزمالة مسبقًا وهو بانتظار القبول.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الطلب: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الطلب: $e')),
        );
      }
    }
  }


  Future<void> _removeColleague() async {
    final me = Supabase.instance.client.auth.currentUser;
    final target = widget.userId;
    if (me == null || target == null || me.id == target) return;
    try {
      await Supabase.instance.client
          .from('friend_requests')
          .update({'status': 'cancelled', 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .or('and(sender_id.eq.${me.id},receiver_id.eq.$target),and(sender_id.eq.$target,receiver_id.eq.${me.id})')
          .eq('status', 'accepted');
      if (!mounted) return;
      setState(() => _friendStatus = 'none');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الزمالة ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إلغاء الزمالة: $e')));
    }
  }

  Future<void> _setBlocked(bool value) async {
    final me = Supabase.instance.client.auth.currentUser;
    final target = widget.userId;
    if (me == null || target == null || me.id == target) return;
    try {
      if (value) {
        await Supabase.instance.client.from('user_blocks').upsert({
          'blocker_id': me.id,
          'blocked_id': target,
        });
        await Supabase.instance.client
            .from('friend_requests')
            .update({'status': 'cancelled', 'updated_at': DateTime.now().toUtc().toIso8601String()})
            .or('and(sender_id.eq.${me.id},receiver_id.eq.$target),and(sender_id.eq.$target,receiver_id.eq.${me.id})')
            .inFilter('status', ['accepted', 'pending']);
      } else {
        await Supabase.instance.client
            .from('user_blocks')
            .delete()
            .eq('blocker_id', me.id)
            .eq('blocked_id', target);
      }
      if (!mounted) return;
      setState(() {
        _blocked = value;
        if (value) _friendStatus = 'none';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? 'تم حظر المستخدم' : 'تم إلغاء الحظر')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الحظر: $e')));
    }
  }

  Future<void> _openChatWithColleague(String name) async {
    final partner = widget.userId;
    if (partner == null) return;
    try {
      final cid = await Supabase.instance.client.rpc(
        'create_direct_conversation',
        params: {'other_user_id': partner},
      );
      if (!mounted || cid == null || cid.toString().isEmpty) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversationId: cid.toString(),
            partnerId: partner,
            partnerName: name,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح الدردشة: ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح الدردشة: $e')));
    }
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
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(isMe ? (ar ? 'حسابي' : 'My Profile') : (ar ? 'الملف الشخصي' : 'Profile'), style: const TextStyle(fontWeight: FontWeight.w800)),
          automaticallyImplyLeading: Navigator.canPop(context),
          actions: [
            if (!isMe)
              IconButton(
                onPressed: _showMore,
                tooltip: ar ? 'المزيد' : 'More',
                icon: const Icon(Icons.more_vert_rounded),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHero(ar, name, image, cover, username, headline, bio, role)),
              SliverToBoxAdapter(child: _buildQuickDashboard(ar)),
              if (isMe || (_bookExists && _bookVisible)) SliverToBoxAdapter(child: _bookButton(ar)),
              if (_editing && isMe) SliverToBoxAdapter(child: _buildEditCard(ar)),
              SliverToBoxAdapter(child: _buildSectionHeader(ar)),
              if (_posts.isEmpty && _sharedPosts.isEmpty)
                SliverToBoxAdapter(child: _emptyPosts(ar))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
                  sliver: SliverList.separated(
                    itemCount: _posts.length + _sharedPosts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => i < _posts.length
                        ? _postCard(_posts[i], ar)
                        : _sharedPostCard(_sharedPosts[i - _posts.length], ar),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _bookButton(bool ar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: const Color(0xFFE7FCF9), child: const Icon(Icons.menu_book_rounded, color: Color(0xFF079E93))),
          title: Text(ar ? 'دفتر الخريجين' : 'Graduation Book', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(ar ? 'اكتب وشارك ذكريات التخرج' : 'Write and share graduation memories'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _openGraduation,
        ),
      ),
    );
  }

  Widget _buildHero(bool ar, dynamic name, String? image, String? cover, String? username, String headline, String bio, String role) {
    return Column(
      children: [
        // Cover is kept clean: editing/settings controls are outside the image
        // so they never hide the top of the cover or the avatar.
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              image: cover != null && cover.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(cover),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    )
                  : null,
            ),
            child: cover == null || cover.isEmpty
                ? const Center(child: Icon(Icons.image_rounded, size: 52, color: Colors.white54))
                : null,
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -52),
          child: Column(
            children: [
              GestureDetector(
                onTap: isMe ? () => _pickImage(cover: false) : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: AppTheme.primaryLight,
                    backgroundImage: image != null && image.isNotEmpty ? NetworkImage(image) : null,
                    child: image == null || image.isEmpty
                        ? Image.asset('assets/branding/zameel_mark.png', width: 70, height: 70)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (isMe)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(cover: true),
                        icon: const Icon(Icons.photo_camera_rounded, size: 19),
                        label: Text(ar ? 'تغيير الغلاف' : 'Change cover'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSettingsScreen(userId: Supabase.instance.client.auth.currentUser!.id)));
                          _load();
                        },
                        icon: const Icon(Icons.settings_rounded, size: 19),
                        label: Text(ar ? 'الإعدادات' : 'Settings'),
                      ),
                    ],
                  ),
                ),
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_blocked)
                        OutlinedButton.icon(onPressed: () => _setBlocked(false), icon: const Icon(Icons.block_rounded), label: Text(ar ? 'إلغاء الحظر' : 'Unblock'))
                      else if (_friendStatus == 'accepted')
                        OutlinedButton.icon(onPressed: _removeColleague, icon: const Icon(Icons.person_remove_alt_1_rounded), label: Text(ar ? 'إلغاء الزمالة' : 'Remove colleague'))
                      else if (_friendStatus == 'pending')
                        OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.hourglass_top_rounded), label: Text(ar ? 'بانتظار الطلب' : 'Request pending'))
                      else if (_friendStatus == 'incoming')
                        OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.mark_email_unread_rounded), label: Text(ar ? 'لديك طلب زمالة' : 'Incoming request'))
                      else
                        FilledButton.icon(onPressed: _sendFriendRequest, icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(ar ? 'إضافة زميل' : 'Add colleague')),
                      if (_friendStatus == 'accepted') ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(onPressed: () => _openChatWithColleague(name.toString()), tooltip: ar ? 'دردشة' : 'Chat', icon: const Icon(Icons.chat_bubble_rounded)),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: Text('$name', textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800))),
                if (role == 'student') ...[const SizedBox(width: 6), const Icon(Icons.verified_rounded, color: Color(0xFF18D4C6), size: 20)],
              ]),
              if (username != null && username.isNotEmpty) Text('@$username', style: const TextStyle(color: AppTheme.textSecondary)),
              if (headline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(headline, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4B5563)))),
              if (bio.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF667085), height: 1.45))),
              if (pString('university').isNotEmpty || pString('college').isNotEmpty || pString('department').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (pString('university').isNotEmpty) _chip(Icons.account_balance_rounded, pString('university')),
                      if (pString('college').isNotEmpty) _chip(Icons.school_rounded, pString('college')),
                      if (pString('department').isNotEmpty) _chip(Icons.menu_book_rounded, pString('department')),
                    ],
                  ),
                ),
              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _editing = !_editing),
                    icon: Icon(_editing ? Icons.close_rounded : Icons.edit_rounded),
                    label: Text(_editing ? (ar ? 'إغلاق التعديل' : 'Close editor') : (ar ? 'تعديل الملف' : 'Edit profile')),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

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
                  _shortcut(Icons.settings_rounded, ar ? 'الإعدادات' : 'Settings', () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSettingsScreen(userId: Supabase.instance.client.auth.currentUser!.id))); _load(); }),
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

  Widget _metric(String label, String value, IconData icon) => Expanded(child: Column(children: [Icon(icon, size: 20, color: AppTheme.primary), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))]));

  Widget _shortcut(IconData icon, String label, VoidCallback onTap) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: SizedBox(width: 72, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE7FCF9), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppTheme.primary)), const SizedBox(height: 5), Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))]))));

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

  Widget _buildSectionHeader(bool ar) => Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 10), child: Row(children: [Text(ar ? 'منشوراتي ومشاركاتي' : 'My posts & shares', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), const Spacer(), Text('${_posts.length + _sharedPosts.length}', style: const TextStyle(color: AppTheme.textSecondary))]));

  Widget _emptyPosts(bool ar) => Padding(padding: const EdgeInsets.all(40), child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Image.asset('assets/branding/zameel_mark.png', width: 70, height: 70), const SizedBox(height: 12), Text(ar ? 'لم تنشر شيئًا بعد' : 'No posts yet', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(ar ? 'ابدأ بمشاركة شيء مفيد مع زملائك.' : 'Share something useful with your classmates.', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary))]))));

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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryLight,
                  backgroundImage: (_profile?['profile_image']?.toString().isNotEmpty == true)
                      ? NetworkImage(_profile!['profile_image'].toString())
                      : null,
                  child: (_profile?['profile_image']?.toString().isNotEmpty == true)
                      ? null
                      : Image.asset('assets/branding/zameel_mark.png', width: 30, height: 30),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_profile?['name']?.toString() ?? (ar ? 'طالب زميل' : 'Zameel Student'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(_profile?['university']?.toString() ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded, color: AppTheme.textSecondary),
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
                Icon(Icons.favorite_rounded, size: 16, color: liked ? Colors.pink : AppTheme.textSecondary),
                const SizedBox(width: 5),
                InkWell(
                  onTap: () => _showLikes(post, ar),
                  child: Text('${post['likes_count'] ?? 0}', style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 15),
                const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 5),
                Text('${post['comments_count'] ?? 0}', style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(width: 15),
                const Icon(Icons.repeat_rounded, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 5),
                Text('${post['shares_count'] ?? 0}', style: const TextStyle(color: AppTheme.textSecondary)),
                const Spacer(),
                Text(_formatDate(post['created_at']), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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

  Widget _postAction(IconData icon, String label, bool active, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(children: [Icon(active ? Icons.favorite_rounded : icon, size: 20, color: active ? Colors.pink : AppTheme.textSecondary), const SizedBox(height: 3), Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.pink : AppTheme.textSecondary))])));

  Future<void> _showLikes(Map<String, dynamic> post, bool ar) async {
    final postId = post['id'];
    if (postId == null) return;
    try {
      final rows = await Supabase.instance.client.from('likes').select('user_id, created_at, users(name, profile_image)').eq('post_id', postId).order('created_at', ascending: false);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => Directionality(
          textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
          child: SizedBox(
            height: 480,
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(16), child: Text(ar ? 'الأشخاص الذين أعجبوا بالمنشور' : 'People who liked this post', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              Expanded(child: rows.isEmpty ? Center(child: Text(ar ? 'لا توجد إعجابات بعد' : 'No likes yet')) : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) {
                final u = rows[i]['users'];
                final name = u is Map ? (u['name']?.toString() ?? 'User') : 'User';
                final image = u is Map ? u['profile_image']?.toString() : null;
                return ListTile(leading: CircleAvatar(backgroundImage: image != null && image.isNotEmpty ? NetworkImage(image) : null, child: image == null || image.isEmpty ? const Icon(Icons.person) : null), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)));
              }))
            ]),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل قائمة الإعجابات: $e')));
    }
  }

  Future<void> _save(Map<String, dynamic> post) async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null || post['id'] == null) return;
    try { await Supabase.instance.client.from('saved_posts').upsert({'user_id': me.id, 'post_id': post['id']}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المنشور ✓'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e'))); }
  }

  Future<void> _share(Map<String, dynamic> post) async {
    final me = Supabase.instance.client.auth.currentUser;
    final postId = post['id'];
    if (me == null || postId == null) return;
    try {
      await Supabase.instance.client.from('shared_posts').upsert({'post_id': postId, 'shared_by': me.id});
      final text = (post['text_ar'] ?? post['text_en'] ?? '').toString();
      await Clipboard.setData(ClipboardData(text: text));
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت مشاركة المنشور في ملفك ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر مشاركة المنشور: $e')));
    }
  }

  Future<void> _unshare(Map<String, dynamic> post) async {
    final me = Supabase.instance.client.auth.currentUser;
    final postId = post['id'];
    if (me == null || postId == null) return;
    try {
      await Supabase.instance.client.from('shared_posts').delete().eq('post_id', postId).eq('shared_by', me.id);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء المشاركة ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إلغاء المشاركة: $e')));
    }
  }

  Widget _sharedPostCard(Map<String, dynamic> post, bool ar) {
    return Card(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
          child: Row(children: [
            const Icon(Icons.repeat_rounded, color: Color(0xFF18D4C6), size: 20),
            const SizedBox(width: 7),
            Expanded(child: Text(ar ? 'منشور تمت مشاركته في ملفك' : 'Post shared to your profile', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF079E93)))),
            IconButton(onPressed: () => _unshare(post), icon: const Icon(Icons.undo_rounded), tooltip: ar ? 'إلغاء المشاركة' : 'Unshare'),
          ]),
        ),
        Padding(padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8), child: _postCard(post, ar)),
      ]),
    );
  }

  String pString(String key) {
    final value = _profile?[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryDark),
          const SizedBox(width: 5),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
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
  void _openGraduation() => Navigator.push(context, MaterialPageRoute(builder: (_) => GraduationBookScreen(ownerId: _profile?['id']?.toString() ?? Supabase.instance.client.auth.currentUser?.id, studentName: pString('name').isEmpty ? 'طالب زميل' : pString('name'), university: pString('university'), major: pString('department'), graduationYear: DateTime.now().year.toString())));

  void _showMore() {
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final targetName = pString('name').isEmpty ? (ar ? 'هذا المستخدم' : 'this user') : pString('name');
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: Text(ar ? 'مشاركة الملف' : 'Share profile'),
              onTap: () {
                Navigator.pop(sheetContext);
                Clipboard.setData(ClipboardData(text: targetName));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ اسم الملف للمشاركة')));
              },
            ),
            if (!_blocked)
              ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.red),
                title: Text(ar ? 'حظر $targetName' : 'Block $targetName'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setBlocked(true);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.lock_open_rounded),
                title: Text(ar ? 'إلغاء الحظر' : 'Unblock user'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setBlocked(false);
                },
              ),
            if (_friendStatus == 'accepted' && !_blocked)
              ListTile(
                leading: const Icon(Icons.person_remove_alt_1_rounded, color: Colors.orange),
                title: Text(ar ? 'إلغاء الزمالة' : 'Remove colleague'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeColleague();
                },
              ),
          ],
        ),
      ),
    );
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
        backgroundColor: AppTheme.background,
        body: items.isEmpty
            ? Center(child: Text(ar ? 'لا يوجد نشاط بعد.' : 'No activity yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFE7FCF9), child: Icon(items[i]['icon'], color: AppTheme.primaryDark)), title: Text(items[i]['title'], style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(items[i]['subtitle'], maxLines: 2, overflow: TextOverflow.ellipsis))),
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
        backgroundColor: AppTheme.background,
        body: ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: achievements.length,
          separatorBuilder: (_, __) => const SizedBox(height: 9),
          itemBuilder: (_, i) {
            final a = achievements[i];
            final unlocked = a.$3 as bool;
            return Card(child: ListTile(leading: CircleAvatar(backgroundColor: unlocked ? const Color(0xFFE7FCF9) : const Color(0xFFF2F4F7), child: Icon(a.$4 as IconData, color: unlocked ? AppTheme.primaryDark : AppTheme.textSecondary)), title: Text(a.$1 as String, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(a.$2 as String), trailing: Icon(unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded, color: unlocked ? Colors.green : AppTheme.textSecondary)));
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
