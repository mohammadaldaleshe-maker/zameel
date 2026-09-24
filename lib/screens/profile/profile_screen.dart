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
import '../../services_social.dart';
import '../../widgets/video_player_widget.dart';
import '../../widgets/post_media_gallery.dart';
import '../../services/post_publish_service.dart';
import '../../services/secure_media_service.dart';
import '../../services/feature_control.dart';

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
  bool _targetOnline = false;

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
      try {
        await db.rpc('touch_my_presence');
        final presence = await db.rpc('get_colleague_presence');
        if (presence is List) _targetOnline = presence.any((p) => p is Map && p['user_id']?.toString() == id && p['is_online'] == true);
      } catch (_) {}

      final row = await db.from('users').select('id,name,username,university,college,department,profile_image,cover_image,headline,bio,account_privacy,default_post_audience,allow_messages,allow_calls,notifications_enabled,gender,role,created_at,updated_at').eq('id', id).maybeSingle();
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
      final resolvedPosts = List<Map<String, dynamic>>.from(posts);
      await SecureMediaService.resolvePosts(resolvedPosts);

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
        await SecureMediaService.resolvePosts(sharedPosts);
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
          if (req.isNotEmpty) {
            final latest = req.first;
            final status = latest['status']?.toString() ?? 'none';
            profile['friend_status'] = status == 'pending' && latest['sender_id']?.toString() != authUser.id
                ? 'incoming'
                : status;
          }
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
          _posts = resolvedPosts;
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
          if (!_following) {
            try {
              await db.from('follows').upsert({'follower_id': me.id, 'following_id': target});
              if (mounted) setState(() { _following = true; _followers++; });
            } catch (_) {}
          }
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

      if (!_following) {
        try {
          await db.from('follows').upsert({'follower_id': me.id, 'following_id': target});
        } catch (_) {}
      }

      if (mounted) setState(() {
        _friendStatus = 'pending';
      });
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
    if (!await FeatureControl.instance.check(context, 'direct_chat')) return;
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
    final name = p['name']?.toString().trim().isNotEmpty == true ? p['name'] : (ar ? 'طالب Zameel' : 'Zameel Student');
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
        body: SafeArea(child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHero(ar, name, image, cover, username, headline, bio, role)),
              SliverToBoxAdapter(child: _buildQuickDashboard(ar)),
              if (isMe && FeatureControl.instance.visible('graduation_book')) SliverToBoxAdapter(child: _bookButton(ar)),
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
        )),
      ),
    );
  }


  Widget _bookButton(bool ar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: AppTheme.primaryLight, child: const Icon(Icons.menu_book_rounded, color: AppTheme.primaryDark)),
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
        Stack(children: [
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
          if (isMe)
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: IconButton.filled(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSettingsScreen(userId: Supabase.instance.client.auth.currentUser!.id)));
                    _load();
                  },
                  icon: const Icon(Icons.settings_rounded),
                  tooltip: ar ? 'إعدادات الحساب' : 'Account settings',
                ),
              ),
            ),
        ]),
        Transform.translate(
          offset: const Offset(0, -52),
          child: Column(
            children: [
              GestureDetector(
                onTap: image != null && image.isNotEmpty ? () => _openImage(image) : null,
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
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(cover: false),
                        icon: const Icon(Icons.account_circle_outlined, size: 19),
                        label: Text(ar ? 'تغيير الصورة' : 'Change photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(cover: true),
                        icon: const Icon(Icons.photo_camera_rounded, size: 19),
                        label: Text(ar ? 'تغيير الغلاف' : 'Change cover'),
                      ),
                    ],
                  ),
                ),
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_blocked)
                        OutlinedButton.icon(onPressed: () => _setBlocked(false), icon: const Icon(Icons.block_rounded), label: Text(ar ? 'إلغاء الحظر' : 'Unblock'))
                      else if (_friendStatus == 'accepted')
                        OutlinedButton.icon(onPressed: _removeColleague, icon: const Icon(Icons.people_alt_rounded), label: Text(ar ? 'زميلان' : 'Colleagues'))
                      else if (_friendStatus == 'pending')
                        OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.hourglass_top_rounded), label: Text(ar ? 'يتابعه • الطلب قيد الانتظار' : 'Following • request pending'))
                      else if (_friendStatus == 'incoming')
                        OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.mark_email_unread_rounded), label: Text(ar ? 'لديك طلب زمالة' : 'Incoming request'))
                      else
                        FilledButton.icon(onPressed: _sendFriendRequest, icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(ar ? 'إضافة زميل' : 'Add colleague')),
                      if (!_blocked) ...[
                        IconButton.filledTonal(
                          onPressed: _toggleFollow,
                          tooltip: _following ? (ar ? 'إلغاء المتابعة' : 'Unfollow') : (ar ? 'متابعة' : 'Follow'),
                          icon: Icon(_following ? Icons.person_rounded : Icons.person_add_outlined),
                        ),
                      ],
                      if (!_blocked && _profile?['allow_messages'] != false) ...[
                        IconButton.filledTonal(onPressed: () => _openChatWithColleague(name.toString()), tooltip: ar ? 'دردشة' : 'Chat', icon: const Icon(Icons.chat_bubble_rounded)),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: Text('$name', textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800))),
                if (role == 'student') ...[const SizedBox(width: 6), const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 20)],
              ]),
              if (!isMe && _targetOnline)
                Padding(padding: const EdgeInsets.only(top: 5), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const CircleAvatar(radius: 5, backgroundColor: Colors.green), const SizedBox(width: 6), Text(ar ? 'متصل الآن' : 'Online now', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700))])),
              if (username != null && username.isNotEmpty) Text('@$username', style: const TextStyle(color: AppTheme.textSecondary)),
              if (headline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(headline, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
              if (bio.isNotEmpty || isMe)
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  padding: const EdgeInsets.all(14),
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.muted.shade200)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Icon(Icons.notes_rounded, size: 19, color: AppTheme.primary), const SizedBox(width: 7), Text(ar ? 'نبذة عني' : 'About me', style: const TextStyle(fontWeight: FontWeight.w800))]),
                    const SizedBox(height: 7),
                    Row(children: [
                      Expanded(child: Text(bio.isEmpty ? (ar ? 'أضف نبذة قصيرة تعرّف زملاءك بك.' : 'Add a short introduction about yourself.') : bio, style: TextStyle(color: bio.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary, height: 1.45))),
                      if (isMe) IconButton(
                        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSettingsScreen(userId: Supabase.instance.client.auth.currentUser!.id))); _load(); },
                        icon: const Icon(Icons.edit_note_rounded),
                        tooltip: ar ? 'تعديل النبذة' : 'Edit bio',
                      ),
                    ]),
                  ]),
                ),
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
            if (isMe) ...[
            const Divider(height: 22),
            Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 12,
                children: [
                  if (FeatureControl.instance.visible('activity_stats')) _shortcut(Icons.insights_rounded, ar ? 'إحصاءاتي' : 'Insights', _openStats),
                  if (FeatureControl.instance.visible('activity_stats')) _shortcut(Icons.timeline_rounded, ar ? 'نشاطي' : 'Activity', _openActivity),
                  if (FeatureControl.instance.visible('activity_stats')) _shortcut(Icons.emoji_events_rounded, ar ? 'إنجازاتي' : 'Achievements', _openAchievements),
                  if (FeatureControl.instance.visible('saved_posts')) _shortcut(Icons.bookmark_rounded, ar ? 'المحفوظات' : 'Saved', _openSaved),
                  if (FeatureControl.instance.visible('books_market')) _shortcut(Icons.local_library_rounded, ar ? 'مكتبتي' : 'My Library', _openMyLibrary),
                  if (FeatureControl.instance.visible('books_market')) _shortcut(Icons.menu_book_rounded, ar ? 'سوق الكتب' : 'Books', _openBooks),
                  if (FeatureControl.instance.visible('groups')) _shortcut(Icons.groups_rounded, ar ? 'مجموعاتي' : 'Groups', _openGroups),
                  if (FeatureControl.instance.visible('clips')) _shortcut(Icons.video_library_rounded, ar ? 'مقاطع الفيديو' : 'Videos', _openSocial),
                  if (FeatureControl.instance.visible('business_partners')) _shortcut(Icons.business_center_rounded, ar ? 'شركاء Zameel' : 'Zameel Partners', _openBusiness),
                  if (FeatureControl.instance.visible('graduation_book')) _shortcut(Icons.school_rounded, ar ? 'كتاب الخريجين' : 'Alumni Book', _openGraduation),
                ],
            ),],
          ]),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Expanded(child: Column(children: [Icon(icon, size: 20, color: AppTheme.primary), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))]));

  Widget _shortcut(IconData icon, String label, VoidCallback onTap) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: SizedBox(width: 72, height: 74, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppTheme.primary)), const SizedBox(height: 5), Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))]))));

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

  Widget _buildSectionHeader(bool ar) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        child: Row(children: [
          Text(isMe ? (ar ? 'منشوراتي ومشاركاتي' : 'My posts & shares') : (ar ? 'المنشورات العامة' : 'Visible posts'),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (isMe)
            IconButton.filledTonal(
              onPressed: () => _composePost(ar),
              tooltip: ar ? 'إنشاء منشور' : 'Create post',
              icon: const Icon(Icons.add_rounded),
            ),
          const SizedBox(width: 6),
          Text('${_posts.length + _sharedPosts.length}',
              style: const TextStyle(color: AppTheme.textSecondary)),
        ]),
      );

  Widget _emptyPosts(bool ar) => Padding(padding: const EdgeInsets.all(40), child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Image.asset('assets/branding/zameel_mark.png', width: 70, height: 70), const SizedBox(height: 12), Text(isMe ? (ar ? 'لم تنشر شيئًا بعد' : 'No posts yet') : (ar ? 'لا توجد منشورات متاحة لك' : 'No posts are visible to you'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(isMe ? (ar ? 'ابدأ بمشاركة شيء مفيد مع زملائك.' : 'Share something useful with your classmates.') : (ar ? 'قد تكون المنشورات خاصة أو مخصصة للزملاء.' : 'Posts may be private or limited to colleagues.'), textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary))]))));

  Widget _postCard(Map<String, dynamic> post, bool ar) {
    final text = (ar ? post['text_ar'] : post['text_en'])?.toString() ?? '';
    final liked = post['liked'] == true;
    final image = post['image_url']?.toString();
    final video = post['video_url']?.toString();
    final rawMedia = post['media_items'];
    final hasOrderedMedia = rawMedia is List && rawMedia.isNotEmpty;
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
                      Text(_profile?['name']?.toString() ?? (ar ? 'طالب Zameel' : 'Zameel Student'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(_profile?['university']?.toString() ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showPostMenu(post, ar),
                  icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.textSecondary),
                ),
              ],
            ),
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InkWell(
                  onTap: () => _openPost(post),
                  child: Text(text, style: const TextStyle(fontSize: 15, height: 1.55)),
                ),
              ),
            if (hasOrderedMedia)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PostMediaGallery(post: post, height: 240),
              ),
            if (!hasOrderedMedia && image != null && image.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => _openImage(image),
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
              ),
            if (!hasOrderedMedia && video != null && video.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: VideoPlayerWidget(videoUrl: video),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 16, color: liked ? AppTheme.accent : AppTheme.textSecondary),
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
                if (FeatureControl.instance.visible('comments')) Expanded(child: _postAction(Icons.chat_bubble_outline_rounded, ar ? 'تعليق' : 'Comment', false, () => _openPost(post))),
                if (FeatureControl.instance.visible('saved_posts')) Expanded(child: _postAction(Icons.bookmark_border_rounded, ar ? 'حفظ' : 'Save', false, () => _save(post))),
                Expanded(child: _postAction(Icons.share_outlined, ar ? 'مشاركة' : 'Share', false, () => _share(post))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _postAction(IconData icon, String label, bool active, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(children: [Icon(active ? Icons.favorite_rounded : icon, size: 20, color: active ? AppTheme.accent : AppTheme.textSecondary), const SizedBox(height: 3), Text(label, style: TextStyle(fontSize: 11, color: active ? AppTheme.accent : AppTheme.textSecondary))])));

  void _openPost(Map<String, dynamic> post) => FeatureControl.instance.open(context, 'comments', () => CommentsScreen(post: post));

  bool _ownsPost(Map<String, dynamic> post) =>
      post['user_id']?.toString() == Supabase.instance.client.auth.currentUser?.id;

  void _openImage(String imageUrl) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
            body: Center(
              child: InteractiveViewer(
                minScale: .8,
                maxScale: 5,
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );

  void _showPostMenu(Map<String, dynamic> post, bool ar) {
    final ownsPost = _ownsPost(post);
    showModalBottomSheet(context: context, builder: (sheetContext) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.open_in_full_rounded), title: Text(ar ? 'فتح المنشور' : 'Open post'), onTap: () { Navigator.pop(sheetContext); _openPost(post); }),
      ListTile(leading: const Icon(Icons.bookmark_add_outlined), title: Text(ar ? 'حفظ المنشور' : 'Save post'), onTap: () { Navigator.pop(sheetContext); _save(post); }),
      ListTile(leading: const Icon(Icons.share_rounded), title: Text(ar ? 'مشاركة المنشور' : 'Share post'), onTap: () { Navigator.pop(sheetContext); _share(post); }),
      if (ownsPost) ListTile(
        leading: const Icon(Icons.visibility_outlined),
        title: Text(ar ? 'تعديل خصوصية المنشور' : 'Change post visibility'),
        subtitle: Text(_audienceLabel(post['audience']?.toString() ?? 'public', ar)),
        onTap: () { Navigator.pop(sheetContext); _choosePostAudience(post, ar); },
      ),
      if (ownsPost && post['audience'] != 'private') ListTile(
        leading: const Icon(Icons.visibility_off_outlined),
        title: Text(ar ? 'إخفاء المنشور — أنا فقط' : 'Hide post — only me'),
        onTap: () async {
          Navigator.pop(sheetContext);
          try {
            await PostPublishService.updateAudience(post['id'].toString(), 'private');
            if (mounted) setState(() => post['audience'] = 'private');
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ar ? 'تعذر إخفاء المنشور' : 'Could not hide post'}: $e')));
          }
        },
      ),
      if (ownsPost) ListTile(leading: const Icon(Icons.delete_outline_rounded, color: Colors.red), title: Text(ar ? 'حذف المنشور' : 'Delete post'), onTap: () async { Navigator.pop(sheetContext); await PostPublishService.deletePost(post['id'].toString()); _load(); }),
    ])));
  }

  String _audienceLabel(String value, bool ar) {
    if (value == 'private') return ar ? 'خاص' : 'Private';
    if (value == 'friends') return ar ? 'للزملاء فقط' : 'Colleagues only';
    return ar ? 'عام' : 'Public';
  }

  Future<void> _choosePostAudience(Map<String, dynamic> post, bool ar) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final value in const ['public', 'friends', 'private'])
            RadioListTile<String>(
              value: value,
              groupValue: post['audience']?.toString() ?? 'public',
              title: Text(_audienceLabel(value, ar)),
              onChanged: (v) => Navigator.pop(sheetContext, v),
            ),
        ]),
      ),
    );
    if (selected == null || selected == post['audience']) return;
    try {
      await PostPublishService.updateAudience(post['id'].toString(), selected);
      if (!mounted) return;
      setState(() => post['audience'] = selected);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'تم تحديث خصوصية المنشور في جميع الصفحات.' : 'Post visibility updated everywhere.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ar ? 'تعذر تحديث الخصوصية' : 'Could not update visibility'}: $e')));
    }
  }

  Future<void> _composePost(bool ar) async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.collections_rounded), title: Text(ar ? 'منشور متعدد الوسائط' : 'Multi-media post'), subtitle: Text(ar ? 'نص + عدة صور + عدة فيديوهات' : 'Text + multiple photos + multiple videos'), onTap: () => Navigator.pop(ctx, 'rich')),
          ListTile(leading: const Icon(Icons.edit_note_rounded), title: Text(ar ? 'منشور نصي' : 'Text post'), onTap: () => Navigator.pop(ctx, 'text')),
          ListTile(leading: const Icon(Icons.image_outlined), title: Text(ar ? 'منشور بصورة' : 'Photo post'), onTap: () => Navigator.pop(ctx, 'image')),
          ListTile(leading: const Icon(Icons.video_library_outlined), title: Text(ar ? 'منشور فيديو' : 'Video post'), onTap: () => Navigator.pop(ctx, 'video')),
          ListTile(leading: const Icon(Icons.auto_awesome_motion_outlined), title: Text(ar ? 'إضافة حالة' : 'Add story'), onTap: () => Navigator.pop(ctx, 'story')),
        ]),
      ),
    );
    if (kind == null) return;
    if (kind == 'rich') return _composeRichPost(ar);
    if (kind == 'text') return _composeTextPost(ar);
    if (kind == 'story') return _composeProfileStory(ar);
    return _composeMediaPost(ar, video: kind == 'video');
  }

  Future<void> _composeRichPost(bool ar) async {
    final controller = TextEditingController();
    var audience = _profile?['default_post_audience']?.toString() ?? 'public';
    final selectedMedia = <PickedPostMedia>[];

    final publish = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(ar ? 'منشور متعدد الوسائط' : 'Multi-media post'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: ar ? 'اكتب نصًا اختياريًا...' : 'Write optional text...',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: audience,
                    decoration: InputDecoration(
                      labelText: ar ? 'الخصوصية' : 'Visibility',
                      border: const OutlineInputBorder(),
                    ),
                    items: const ['public', 'friends', 'private']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_audienceLabel(value, ar)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => audience = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: selectedMedia.length >= PostPublishService.maxMediaItems
                          ? null
                          : () async {
                              final result = await PostPublishService.pickMultipleMedia(
                                limit: PostPublishService.maxMediaItems - selectedMedia.length,
                              );
                              if (result.isEmpty) return;

                              final existing = selectedMedia
                                  .map((file) => '${file.name}:${file.path}')
                                  .toSet();
                              for (final file in result) {
                                if (!PostPublishService.isSupportedFile(file)) continue;
                                final key = '${file.name}:${file.path}';
                                if (!existing.add(key)) continue;
                                if (selectedMedia.length >= PostPublishService.maxMediaItems) break;
                                selectedMedia.add(file);
                              }
                              setDialogState(() {});
                            },
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: Text(
                        ar
                            ? 'إضافة صور وفيديوهات (${selectedMedia.length}/${PostPublishService.maxMediaItems})'
                            : 'Add photos & videos (${selectedMedia.length}/${PostPublishService.maxMediaItems})',
                      ),
                    ),
                  ),
                  if (selectedMedia.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...List.generate(selectedMedia.length, (index) {
                      final file = selectedMedia[index];
                      final video = PostPublishService.isVideoFile(file);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          video ? Icons.videocam_rounded : Icons.image_rounded,
                          color: video ? AppTheme.primaryDark : AppTheme.primary,
                        ),
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: ar ? 'إزالة' : 'Remove',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            selectedMedia.removeAt(index);
                            setDialogState(() {});
                          },
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(ar ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty && selectedMedia.isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: Text(ar ? 'نشر' : 'Publish'),
            ),
          ],
        ),
      ),
    );

    final text = controller.text.trim();
    controller.dispose();
    if (publish != true) return;

    try {
      await PostPublishService.publishPost(
        text: text,
        audience: audience,
        media: List<PickedPostMedia>.from(selectedMedia),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ar ? 'تم نشر المنشور ✓' : 'Post published ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ar ? 'تعذر النشر' : 'Could not publish'}: $e')),
        );
      }
    }
  }

  Future<String?> _newAudience(bool ar) async {
    var audience = _profile?['default_post_audience']?.toString() ?? 'public';
    return showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(builder: (_, setLocal) => AlertDialog(
      title: Text(ar ? 'من يمكنه مشاهدة المحتوى؟' : 'Who can see this?'),
      content: DropdownButtonFormField<String>(value: audience, decoration: const InputDecoration(border: OutlineInputBorder()), items: const ['public','friends','private'].map((v) => DropdownMenuItem(value: v, child: Text(_audienceLabel(v, ar)))).toList(), onChanged: (v) { if(v!=null)setLocal(() => audience=v); }),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ar ? 'إلغاء' : 'Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx,audience), child: Text(ar ? 'متابعة' : 'Continue'))],
    )));
  }

  Future<void> _composeMediaPost(bool ar, {required bool video}) async {
    final media = video
        ? await PostPublishService.pickMultipleVideos()
        : await PostPublishService.pickMultipleImages();
    if (media.isEmpty) return;

    final audience = await _newAudience(ar);
    if (audience == null) return;

    final caption = TextEditingController();
    final publish = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          video
              ? (ar ? 'نشر فيديوهات' : 'Publish videos')
              : (ar ? 'نشر صور' : 'Publish photos'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ar
                  ? 'تم اختيار ${media.length} ملف.'
                  : '${media.length} file(s) selected.',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: caption,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: ar ? 'أضف وصفًا اختياريًا' : 'Add an optional caption',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ar ? 'نشر' : 'Publish'),
          ),
        ],
      ),
    );
    final text = caption.text.trim();
    caption.dispose();
    if (publish != true) return;

    try {
      await PostPublishService.publishPost(
        text: text,
        audience: audience,
        media: media,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ar
                  ? 'تم نشر ${media.length} ملف وسائط ✓'
                  : '${media.length} media item(s) published ✓',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ar ? 'تعذر النشر' : 'Could not publish'}: $e')),
        );
      }
    }
  }

  Future<void> _composeProfileStory(bool ar) async {
    final type=await showModalBottomSheet<String>(context:context,builder:(ctx)=>SafeArea(child:Wrap(children:[ListTile(leading:const Icon(Icons.image),title:Text(ar?'حالة بصورة':'Photo story'),onTap:()=>Navigator.pop(ctx,'image')),ListTile(leading:const Icon(Icons.videocam),title:Text(ar?'حالة فيديو':'Video story'),onTap:()=>Navigator.pop(ctx,'video'))])));
    if(type==null)return;
    final file=type=='video'?await _picker.pickVideo(source:ImageSource.gallery,maxDuration:const Duration(seconds:60)):await _picker.pickImage(source:ImageSource.gallery,imageQuality:88);
    if(file==null)return;
    final audience=await _newAudience(ar);if(audience==null)return;
    try{final id=await ZameelSocialService.createStoryFile(file:file,mediaType:type,caption:'',audience:audience);if(id==null)throw Exception('upload_failed');if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ar?'تم نشر الحالة ✓':'Story published ✓')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${ar?'تعذر نشر الحالة':'Could not publish story'}: $e')));} 
  }

  Future<void> _composeTextPost(bool ar) async {
    final controller = TextEditingController();
    var audience = _profile?['default_post_audience']?.toString() ?? 'public';
    final publish = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(ar ? 'إنشاء منشور' : 'Create post'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: controller, autofocus: true, maxLines: 5, decoration: InputDecoration(hintText: ar ? 'بماذا تفكر؟' : "What's on your mind?", border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: audience,
              decoration: InputDecoration(labelText: ar ? 'الخصوصية' : 'Visibility', border: const OutlineInputBorder()),
              items: const ['public', 'friends', 'private'].map((v) => DropdownMenuItem(value: v, child: Text(_audienceLabel(v, ar)))).toList(),
              onChanged: (v) { if (v != null) setDialogState(() => audience = v); },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(ar ? 'نشر' : 'Publish')),
          ],
        ),
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (publish != true || text.isEmpty) return;
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;
    try {
      await Supabase.instance.client.from('posts').insert({'user_id': me.id, 'type': 'text', 'text_ar': text, 'text_en': text, 'audience': audience});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ar ? 'تعذر نشر المنشور' : 'Could not publish'}: $e')));
    }
  }

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
    if (!await FeatureControl.instance.check(context, 'saved_posts')) return;
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null || post['id'] == null) return;
    try { await Supabase.instance.client.from('saved_posts').upsert({'user_id': me.id, 'post_id': post['id']}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المنشور ✓'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(FeatureControl.errorMessage(e, 'تعذر الحفظ')))); }
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
            const Icon(Icons.repeat_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 7),
            Expanded(child: Text(ar ? 'منشور تمت مشاركته في ملفك' : 'Post shared to your profile', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryDark))),
            if (isMe) IconButton(onPressed: () => _unshare(post), icon: const Icon(Icons.undo_rounded), tooltip: ar ? 'إلغاء المشاركة' : 'Unshare'),
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

  void _openActivity() => FeatureControl.instance.open(context, 'activity_stats', () => ProfileActivityScreen(posts: _posts, ar: Provider.of<LanguageProvider>(context, listen: false).isArabic));
  void _openAchievements() => FeatureControl.instance.open(context, 'activity_stats', () => ProfileAchievementsScreen(posts: _posts.length, likes: _likesReceived, followers: _followers, clips: _clips, ar: Provider.of<LanguageProvider>(context, listen: false).isArabic));
  void _openStats() => FeatureControl.instance.open(context, 'activity_stats', () => StatsScreen(postsCount: _posts.length, likesCount: _likesReceived, commentsCount: _comments, friendsCount: _followers, savedBooksCount: _saved, activeDays: 0));
  Future<void> _openSaved() async {
    if (!await FeatureControl.instance.check(context, 'saved_posts')) return;
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
      await SecureMediaService.resolvePosts(saved);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => FeatureControl.instance.page('saved_posts', SavedPostsScreen(savedPosts: saved))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(FeatureControl.errorMessage(e, 'تعذر فتح المحفوظات'))));
    }
  }
  void _openBooks() => FeatureControl.instance.open(context, 'books_market', () => const BooksScreen());
  void _openMyLibrary() => FeatureControl.instance.open(context, 'books_market', () => const MyLibraryScreen());
  void _openGroups() => FeatureControl.instance.open(context, 'groups', () => const GroupsScreen());
  void _openSocial() => FeatureControl.instance.open(context, 'clips', () => ZameelSocialStudio(isArabic: Provider.of<LanguageProvider>(context, listen: false).isArabic));
  void _openBusiness() => FeatureControl.instance.open(context, 'business_partners', () => const BusinessScreen());
  void _openGraduation() => FeatureControl.instance.open(context, 'graduation_book', () => GraduationBookScreen(ownerId: _profile?['id']?.toString() ?? Supabase.instance.client.auth.currentUser?.id, studentName: pString('name').isEmpty ? 'طالب Zameel' : pString('name'), university: pString('university'), major: pString('department'), graduationYear: DateTime.now().year.toString()));

  void _showMore() {
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final targetName = pString('name').isEmpty ? (ar ? 'هذا المستخدم' : 'this user') : pString('name');
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.local_library_rounded),
                title: Text(ar ? 'مكتبتي' : 'My Library'),
                onTap: () { Navigator.pop(sheetContext); _openMyLibrary(); },
              ),
            ],
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
                itemBuilder: (_, i) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: AppTheme.primaryLight, child: Icon(items[i]['icon'], color: AppTheme.primaryDark)), title: Text(items[i]['title'], style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(items[i]['subtitle'], maxLines: 2, overflow: TextOverflow.ellipsis))),
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
      (ar ? 'أول منشور' : 'First post', ar ? 'انضممت إلى مجتمع Zameel وشاركت أول منشور.' : 'You shared your first Zameel post.', posts >= 1, Icons.edit_note_rounded),
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
            return Card(child: ListTile(leading: CircleAvatar(backgroundColor: unlocked ? AppTheme.primaryLight : AppTheme.surfaceAlt, child: Icon(a.$4 as IconData, color: unlocked ? AppTheme.primaryDark : AppTheme.textSecondary)), title: Text(a.$1 as String, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(a.$2 as String), trailing: Icon(unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded, color: unlocked ? Colors.green : AppTheme.textSecondary)));
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
