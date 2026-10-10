import 'package:zameel/widgets/copyable_text.dart';
import '../../widgets/post_media_frame.dart';
import 'package:zameel/theme/appearance_controller.dart';
import 'package:zameel/widgets/verified_name.dart';
import '../../widgets/cached_media_image.dart';
import 'dart:async';
import 'profile_photo_screen.dart';
import '../../widgets/compact_post.dart';
import '../promotions/promotion_request_screen.dart';
import '../../widgets/profile_image_cropper.dart';
import '../social/shorts_profile_panel.dart';
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
import '../../widgets/post_report_menu.dart';
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

  bool _showShorts = false;
  bool _showSavedShorts = false;

  bool get isMe =>
      widget.userId == null ||
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
    _promotionBadgeExpiry?.cancel();
    super.dispose();
  }

  String? _profileError;
  bool _refreshing = false;
  bool _contentLoading = false;
  bool _morePosts = false, _moreShared = false;
  bool _loadingMore = false;
  int _postOffset = 0, _sharedOffset = 0;
  final Map<String, DateTime> _promotionEnds = {};
  Timer? _promotionBadgeExpiry;
  void _schedulePromotionBadgeExpiry() {
    _promotionBadgeExpiry?.cancel();
    final ends = _promotionEnds.values
        .where((end) => end.isAfter(DateTime.now()))
        .toList()
      ..sort();
    if (ends.isEmpty) return;
    _promotionBadgeExpiry = Timer(ends.first.difference(DateTime.now()), () {
      if (!mounted) return;
      setState(() =>
          _promotionEnds.removeWhere((_, end) => !end.isAfter(DateTime.now())));
      _schedulePromotionBadgeExpiry();
    });
  }

  Future<T> _optional<T>(Future<T> task, T fallback) async {
    try {
      return await task.timeout(const Duration(seconds: 15));
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _presence(String id) async {
    try {
      final db = Supabase.instance.client;
      await db.rpc('touch_my_presence').timeout(const Duration(seconds: 8));
      final rows = await db
          .rpc('get_colleague_presence')
          .timeout(const Duration(seconds: 8));
      if (mounted && rows is List)
        setState(() => _targetOnline = rows.any((p) =>
            p is Map &&
            p['user_id']?.toString() == id &&
            p['is_online'] == true));
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    _profileError = null;
    if (mounted && _profile == null) setState(() => _loading = true);
    final db = Supabase.instance.client;
    final authUser = db.auth.currentUser;
    final id = widget.userId ?? authUser?.id;
    try {
      if (id == null) return;
      unawaited(_presence(id));
      final row = await db
          .from('users')
          .select(
              'id,name,username,university,college,department,profile_image,cover_image,headline,bio,account_privacy,default_post_audience,allow_messages,allow_calls,notifications_enabled,gender,role,account_type,verification_expires_at,created_at,updated_at')
          .eq('id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      if (!mounted || db.auth.currentUser?.id != authUser?.id) return;
      if (row == null) {
        setState(() => _profile = null);
        return;
      }
      final profile = Map<String, dynamic>.from(row);
      if (id == authUser?.id) {
        VerificationDirectory.instance
            .updateOwn(id, profile['verification_expires_at']?.toString());
      }
      // The users SELECT policy has already checked privacy and blocking.
      // Show the header without waiting for counters, presence or media signing.
      setState(() {
        _profile = profile;
        _loading = false;
        _contentLoading = true;
      });
      _fillControllers(profile);
      final stats = Future.wait<dynamic>([
        _optional(db.from('follows').count().eq('following_id', id), 0),
        _optional(db.from('follows').count().eq('follower_id', id), 0),
        isMe
            ? _optional(db.from('saved_posts').count().eq('user_id', id), 0)
            : Future.value(0),
        _optional(db.from('clips').count().eq('user_id', id), 0),
        _optional(db.from('posts').count().eq('user_id', id), 0),
        _optional(
            db
                .from('graduation_books')
                .select('id,is_public')
                .eq('owner_id', id)
                .maybeSingle(),
            null),
        if (!isMe && authUser != null) ...[
          _optional(
              db
                  .from('follows')
                  .select('follower_id')
                  .eq('follower_id', authUser.id)
                  .eq('following_id', id)
                  .maybeSingle(),
              null),
          _optional(
              db
                  .from('friend_requests')
                  .select('id,sender_id,receiver_id,status')
                  .or('and(sender_id.eq.${authUser.id},receiver_id.eq.$id),and(sender_id.eq.$id,receiver_id.eq.${authUser.id})')
                  .order('created_at', ascending: false)
                  .limit(1),
              <Map<String, dynamic>>[]),
          _optional(
              db
                  .from('user_blocks')
                  .select('id')
                  .eq('blocker_id', authUser.id)
                  .eq('blocked_id', id)
                  .maybeSingle(),
              null),
        ],
      ]);
      final totalsTask = _optional(
          db.rpc('zameel_profile_post_totals', params: {'p_owner': id}),
          <String, dynamic>{});
      final content = _loadPage(id, reset: true);
      final promotions = _loadPromotionBadges(id);
      final counters = await stats;
      if (!mounted || db.auth.currentUser?.id != authUser?.id) return;
      setState(() {
        _followers = counters[0];
        _followingCount = counters[1];
        _saved = counters[2];
        _clips = counters[3];
        profile['posts_count'] = counters[4];
        profile['followers_count'] = _followers;
        profile['following_count'] = _followingCount;
        profile['saved_count'] = _saved;
        profile['clips_count'] = _clips;
        final book = counters[5];
        _bookExists = book != null;
        _bookVisible = book == null || book['is_public'] != false;
        if (!isMe && authUser != null) {
          _following = counters[6] != null;
          final requests = counters[7] as List;
          _friendStatus = requests.isEmpty
              ? 'none'
              : requests.first['status'] == 'pending' &&
                      requests.first['sender_id'] != authUser.id
                  ? 'incoming'
                  : requests.first['status']?.toString() ?? 'none';
          _blocked = counters[8] != null;
        }
      });
      await Future.wait([content, promotions]);
      final totals = await totalsTask;
      if (mounted && totals is Map)
        setState(() {
          _likesReceived = ((totals['likes'] ?? _likesReceived) as num).toInt();
          _comments = ((totals['comments'] ?? _comments) as num).toInt();
        });
    } catch (e) {
      _profileError = 'Unable to load profile';
      debugPrint('Profile load error: $e');
    } finally {
      _refreshing = false;
      if (mounted)
        setState(() {
          _loading = false;
          _contentLoading = false;
        });
    }
  }

  Future<void> _loadPromotionBadges(String id) async {
    try {
      final db = Supabase.instance.client;
      final rows = await db.rpc('zameel_visible_promotion_badges',
          params: {'p_owner': id}).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _promotionEnds.clear();
        for (final row in rows as List) {
          final end = DateTime.tryParse('${row['ends_at']}');
          if (end != null) _promotionEnds['${row['post_id']}'] = end;
        }
      });
      _schedulePromotionBadgeExpiry();
    } catch (_) {}
  }

  Future<void> _loadPage(String id, {bool reset = false}) async {
    if (_loadingMore) return;
    _loadingMore = true;
    final db = Supabase.instance.client;
    final sessionId = db.auth.currentUser?.id;
    try {
      final po = reset ? 0 : _postOffset, so = reset ? 0 : _sharedOffset;
      final pages = await Future.wait<dynamic>([
        if (reset || _morePosts)
          db
              .from('posts')
              .select('*, users(name,profile_image,verification_expires_at)')
              .eq('user_id', id)
              .order('created_at', ascending: false)
              .order('id', ascending: false)
              .range(po, po + 29)
              .timeout(const Duration(seconds: 15))
        else
          Future.value(<Map<String, dynamic>>[]),
        if (reset || _moreShared)
          _optional(
              db
                  .from('shared_posts')
                  .select(
                      'id,post_id,created_at,posts(*, users(name,profile_image,verification_expires_at))')
                  .eq('shared_by', id)
                  .order('created_at', ascending: false)
                  .order('id', ascending: false)
                  .range(so, so + 29),
              <Map<String, dynamic>>[])
        else
          Future.value(<Map<String, dynamic>>[]),
      ]);
      final posts = List<Map<String, dynamic>>.from(pages[0]);
      final sharedRows = List<Map<String, dynamic>>.from(pages[1]);
      final shared = sharedRows
          .where((r) => r['posts'] is Map)
          .map((r) => <String, dynamic>{
                ...Map<String, dynamic>.from(r['posts']),
                'shared_row_id': r['id'],
                'shared_by_me': true,
                'shared_at': r['created_at']
              })
          .toList();
      // Media widgets resolve only visible items; signing is not a page barrier.
      if (!mounted || db.auth.currentUser?.id != sessionId) return;
      setState(() {
        if (reset) {
          _posts = posts;
          _sharedPosts = shared;
        } else {
          _posts.addAll(posts);
          _sharedPosts.addAll(shared);
        }
        _postOffset = po + posts.length;
        _sharedOffset = so + sharedRows.length;
        _morePosts = posts.length == 30;
        _moreShared = sharedRows.length == 30;
        _likedStateLoaded = false;
        _contentLoading = false;
      });
    } finally {
      _loadingMore = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _openProfilePhoto(String url, String kind) async {
    final owner = _profile?['id']?.toString();
    if (owner == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ProfilePhotoScreen(ownerId: owner, kind: kind, imageUrl: url)));
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
        'username': _username.text.trim().isEmpty
            ? null
            : _username.text.trim().toLowerCase(),
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
        _profile = {
          ...?_profile,
          'name': _name.text.trim(),
          'username': _username.text.trim(),
          'headline': _headline.text.trim(),
          'bio': _bio.text.trim(),
          'university': _university.text.trim(),
          'college': _college.text.trim(),
          'department': _department.text.trim(),
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الملف الشخصي بنجاح ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر حفظ التعديلات: $e')));
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
      final original = await image.readAsBytes();
      if (!mounted) return;
      final bytes = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(
              builder: (_) => ProfileImageCropper(
                  bytes: original,
                  cover: cover,
                  arabic: Provider.of<LanguageProvider>(context, listen: false)
                      .isArabic)));
      if (bytes == null || !mounted) return;
      const ext = 'png';
      const contentType = 'image/png';
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
          content: Text(
              cover ? 'تم تحديث صورة الغلاف ✓' : 'تم تحديث الصورة الشخصية ✓'),
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
              await db
                  .from('follows')
                  .upsert({'follower_id': me.id, 'following_id': target});
              if (mounted)
                setState(() {
                  _following = true;
                  _followers++;
                });
            } catch (_) {}
          }
          if (senderId == me.id) {
            if (mounted) setState(() => _friendStatus = 'pending');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'تم إرسال طلب الزمالة مسبقًا وهو بانتظار القبول.')),
              );
            }
          } else {
            if (mounted) setState(() => _friendStatus = 'incoming');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'لدى هذا المستخدم طلب زمالة مرسل إليك. افتح قسم الزملاء لقبوله.')),
              );
            }
          }
          return;
        }
      }

      final targetRow =
          await db.from('users').select('name').eq('id', target).maybeSingle();

      await db.from('friend_requests').insert({
        'sender_id': me.id,
        'receiver_id': target,
        'sender_name': me.userMetadata?['name']?.toString() ?? 'زميل',
        'receiver_name': targetRow?['name']?.toString() ?? 'زميل',
        'status': 'pending',
      });

      if (!_following) {
        try {
          await db
              .from('follows')
              .upsert({'follower_id': me.id, 'following_id': target});
        } catch (_) {}
      }

      if (mounted)
        setState(() {
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
            const SnackBar(
                content:
                    Text('تم إرسال طلب الزمالة مسبقًا وهو بانتظار القبول.')),
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
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toUtc().toIso8601String()
          })
          .or('and(sender_id.eq.${me.id},receiver_id.eq.$target),and(sender_id.eq.$target,receiver_id.eq.${me.id})')
          .eq('status', 'accepted');
      if (!mounted) return;
      setState(() => _friendStatus = 'none');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم إلغاء الزمالة ✓')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر إلغاء الزمالة: $e')));
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
            .update({
              'status': 'cancelled',
              'updated_at': DateTime.now().toUtc().toIso8601String()
            })
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value ? 'تم حظر المستخدم' : 'تم إلغاء الحظر')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر تحديث الحظر: $e')));
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر فتح الدردشة: ${e.message}')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر فتح الدردشة: $e')));
    }
  }

  Future<void> _toggleFollow() async {
    final me = Supabase.instance.client.auth.currentUser;
    final target = widget.userId;
    if (me == null || target == null || me.id == target) return;
    final db = Supabase.instance.client;
    try {
      if (_following) {
        await db
            .from('follows')
            .delete()
            .eq('follower_id', me.id)
            .eq('following_id', target);
        if (mounted)
          setState(() {
            _following = false;
            _followers = _followers > 0 ? _followers - 1 : 0;
          });
      } else {
        await db
            .from('follows')
            .upsert({'follower_id': me.id, 'following_id': target});
        if (mounted)
          setState(() {
            _following = true;
            _followers++;
          });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر تحديث المتابعة: $e')));
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final me = Supabase.instance.client.auth.currentUser;
    final id = post['id'];
    if (me == null || id == null) return;
    if (post['user_id'] == _profile?['id']) post['users'] ??= _profile;
    final liked = post['liked'] == true;
    final oldCount = ((post['likes_count'] ?? 0) as num).toInt();
    setState(() {
      post['liked'] = !liked;
      post['likes_count'] =
          liked ? (oldCount > 0 ? oldCount - 1 : 0) : oldCount + 1;
    });
    try {
      if (liked) {
        await Supabase.instance.client
            .from('likes')
            .delete()
            .eq('user_id', me.id)
            .eq('post_id', id);
      } else {
        await Supabase.instance.client
            .from('likes')
            .upsert({'user_id': me.id, 'post_id': id});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        post['liked'] = liked;
        post['likes_count'] = oldCount;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر تسجيل الإعجاب: $e')));
    }
  }

  Future<void> _prepareLikedState() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null || _posts.isEmpty) return;
    try {
      final rows = await Supabase.instance.client
          .from('likes')
          .select('post_id')
          .eq('user_id', me.id);
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
    AppearanceScope.observe(context);
    final ar = Provider.of<LanguageProvider>(context).isArabic;
    if (!_loading &&
        _profile != null &&
        _posts.isNotEmpty &&
        !_likedStateLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_likedStateLoaded) _prepareLikedState();
      });
    }

    if (_loading) return const _ProfileLoading();
    if (_profile == null && _profileError != null)
      return Scaffold(
          appBar: AppBar(),
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ar ? 'تعذر تحميل الملف الشخصي' : 'Unable to load profile'),
            TextButton(
                onPressed: _load, child: Text(ar ? 'إعادة المحاولة' : 'Retry'))
          ])));
    if (_profile == null) return _NotFound(ar: ar);

    final p = _profile!;
    final name = p['name']?.toString().trim().isNotEmpty == true
        ? p['name']
        : (ar ? 'طالب Zameel' : 'Zameel Student');
    final image = p['profile_image']?.toString();
    final cover = p['cover_image']?.toString();
    final username = p['username']?.toString();
    final headline = p['headline']?.toString() ?? '';
    final bio = p['bio']?.toString() ?? '';
    final role = p['role']?.toString() ?? 'student';

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
            child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                  child: _buildHero(
                      ar, name, image, cover, username, headline, bio, role)),
              SliverToBoxAdapter(child: _buildQuickDashboard(ar)),
              if (isMe && FeatureControl.instance.visible('graduation_book'))
                SliverToBoxAdapter(child: _bookButton(ar)),
              if (FeatureControl.instance.visible('clips'))
                SliverToBoxAdapter(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      TextButton(
                          onPressed: () => setState(() => _showShorts = false),
                          child: Text(ar ? 'المنشورات' : 'Posts')),
                      TextButton(
                          onPressed: () => setState(() {
                                _showShorts = true;
                                _showSavedShorts = false;
                              }),
                          child: Text(ar ? 'زميل شورتس' : 'Zameel Shorts')),
                      if (isMe)
                        TextButton(
                            onPressed: () => setState(() {
                                  _showShorts = true;
                                  _showSavedShorts = true;
                                }),
                            child:
                                Text(ar ? 'الشورتس المحفوظة' : 'Saved Shorts')),
                    ])),
              if (_showShorts && FeatureControl.instance.visible('clips'))
                SliverToBoxAdapter(
                    child: ShortsProfilePanel(
                        key: ValueKey('shorts_$_showSavedShorts'),
                        userId: widget.userId ??
                            Supabase.instance.client.auth.currentUser!.id,
                        ar: ar,
                        savedOnly: isMe && _showSavedShorts))
              else ...[
                SliverToBoxAdapter(child: _buildSectionHeader(ar)),
                if (_contentLoading && _posts.isEmpty && _sharedPosts.isEmpty)
                  const SliverToBoxAdapter(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator())))
                else if (_posts.isEmpty && _sharedPosts.isEmpty)
                  SliverToBoxAdapter(child: _emptyPosts(ar))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
                    sliver: SliverList.separated(
                      itemCount: _posts.length + _sharedPosts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => i < _posts.length
                          ? _postCard(_posts[i], ar)
                          : _sharedPostCard(
                              _sharedPosts[i - _posts.length], ar),
                    ),
                  ),
                if (_morePosts || _moreShared)
                  SliverToBoxAdapter(
                      child: TextButton(
                          onPressed: _loadingMore
                              ? null
                              : () async {
                                  try {
                                    await _loadPage(_profile!['id'].toString());
                                  } catch (_) {
                                    if (mounted)
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(ar
                                                  ? 'تعذر تحميل المزيد. حاول مجددًا.'
                                                  : 'Unable to load more. Try again.')));
                                  }
                                },
                          child: Text(_loadingMore
                              ? (ar ? 'جارٍ التحميل…' : 'Loading…')
                              : (ar ? 'عرض المزيد' : 'Load more')))),
              ],
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
          leading: CircleAvatar(
              backgroundColor: AppTheme.primaryLight,
              child: const Icon(Icons.menu_book_rounded,
                  color: AppTheme.primaryDark)),
          title: Text(ar ? 'دفتر الخريجين' : 'Graduation Book',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(ar
              ? 'اكتب وشارك ذكريات التخرج'
              : 'Write and share graduation memories'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _openGraduation,
        ),
      ),
    );
  }

  Widget _buildHero(bool ar, dynamic name, String? image, String? cover,
      String? username, String headline, String bio, String role) {
    return Column(
      children: [
        // Cover is kept clean: editing/settings controls are outside the image
        // so they never hide the top of the cover or the avatar.
        Stack(children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(28)),
            child: GestureDetector(
              onTap: cover != null && cover.isNotEmpty
                  ? () => _openProfilePhoto(cover, 'cover')
                  : null,
              child: Container(
                height: MediaQuery.sizeOf(context).width / 2,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  image: cover != null && cover.isNotEmpty
                      ? DecorationImage(
                          image: ResizeImage(NetworkImage(cover),
                              width: (MediaQuery.sizeOf(context).width *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .round()
                                  .clamp(1, 1440)),
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        )
                      : null,
                ),
                child: cover == null || cover.isEmpty
                    ? const Center(
                        child: Icon(Icons.image_rounded,
                            size: 52, color: Colors.white54))
                    : null,
              ),
            ),
          ),
          if (isMe)
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: IconButton.filled(
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProfileSettingsScreen(
                                userId: Supabase
                                    .instance.client.auth.currentUser!.id)));
                    _load();
                  },
                  icon: const Icon(Icons.settings_rounded),
                  tooltip: ar ? 'إعدادات الحساب' : 'Account settings',
                ),
              ),
            ),
        ]),
        Column(
          children: [
            SizedBox(
                height: 64,
                child: OverflowBox(
                    maxHeight: 112,
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: image != null && image.isNotEmpty
                          ? () => _openProfilePhoto(image, 'avatar')
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle),
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: AppTheme.primaryLight,
                          backgroundImage: image != null && image.isNotEmpty
                              ? ResizeImage(NetworkImage(image),
                                  width: (104 *
                                          MediaQuery.devicePixelRatioOf(
                                              context))
                                      .round()
                                      .clamp(1, 512))
                              : null,
                          child: image == null || image.isEmpty
                              ? Image.asset('assets/branding/zameel_mark.png',
                                  width: 70, height: 70)
                              : null,
                        ),
                      ),
                    ))),
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
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40)),
                      icon: const Icon(Icons.account_circle_outlined, size: 19),
                      label: Text(ar ? 'تغيير الصورة' : 'Change photo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(cover: true),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40)),
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
                      OutlinedButton.icon(
                          onPressed: () => _setBlocked(false),
                          icon: const Icon(Icons.block_rounded),
                          label: Text(ar ? 'إلغاء الحظر' : 'Unblock'))
                    else if (_friendStatus == 'accepted')
                      OutlinedButton.icon(
                          onPressed: _removeColleague,
                          icon: const Icon(Icons.people_alt_rounded),
                          label: Text(ar ? 'زميلان' : 'Colleagues'))
                    else if (_friendStatus == 'pending')
                      OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.hourglass_top_rounded),
                          label: Text(ar
                              ? 'يتابعه • الطلب قيد الانتظار'
                              : 'Following • request pending'))
                    else if (_friendStatus == 'incoming')
                      OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.mark_email_unread_rounded),
                          label:
                              Text(ar ? 'لديك طلب زمالة' : 'Incoming request'))
                    else
                      FilledButton.icon(
                          onPressed: _sendFriendRequest,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: Text(ar ? 'إضافة زميل' : 'Add colleague')),
                    if (!_blocked) ...[
                      IconButton.filledTonal(
                        onPressed: _toggleFollow,
                        tooltip: _following
                            ? (ar ? 'إلغاء المتابعة' : 'Unfollow')
                            : (ar ? 'متابعة' : 'Follow'),
                        icon: Icon(_following
                            ? Icons.person_rounded
                            : Icons.person_add_outlined),
                      ),
                    ],
                    if (!_blocked && _profile?['allow_messages'] != false) ...[
                      IconButton.filledTonal(
                          onPressed: () =>
                              _openChatWithColleague(name.toString()),
                          tooltip: ar ? 'دردشة' : 'Chat',
                          icon: const Icon(Icons.chat_bubble_rounded)),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                  child: VerifiedName(
                      userId: widget.userId,
                      child: Text('$name',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w800)))),
              const SizedBox.shrink(),
            ]),
            if (!isMe && _targetOnline)
              Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircleAvatar(
                            radius: 5, backgroundColor: Colors.green),
                        const SizedBox(width: 6),
                        Text(ar ? 'متصل الآن' : 'Online now',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w700))
                      ])),
            if (username != null && username.isNotEmpty)
              Text('@$username',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (headline.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(headline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant))),
            if (bio.isNotEmpty || isMe)
              Container(
                margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                padding: const EdgeInsets.all(14),
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.adaptiveMuted.shade200)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.notes_rounded,
                            size: 19, color: AppTheme.primary),
                        const SizedBox(width: 7),
                        Text(ar ? 'نبذة عني' : 'About me',
                            style: TextStyle(fontWeight: FontWeight.w800))
                      ]),
                      const SizedBox(height: 7),
                      Row(children: [
                        Expanded(
                            child: Text(
                                bio.isEmpty
                                    ? (ar
                                        ? 'أضف نبذة قصيرة تعرّف زملاءك بك.'
                                        : 'Add a short introduction about yourself.')
                                    : bio,
                                style: TextStyle(
                                    color: bio.isEmpty
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    height: 1.45))),
                        if (isMe)
                          IconButton(
                            onPressed: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ProfileSettingsScreen(
                                          userId: Supabase.instance.client.auth
                                              .currentUser!.id)));
                              _load();
                            },
                            icon: const Icon(Icons.edit_note_rounded),
                            tooltip: ar ? 'تعديل النبذة' : 'Edit bio',
                          ),
                      ]),
                    ]),
              ),
            if (pString('university').isNotEmpty ||
                pString('college').isNotEmpty ||
                pString('department').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (pString('account_type') == 'graduate')
                      _chip(Icons.school_rounded, ar ? 'خريج' : 'Graduate'),
                    if (pString('university').isNotEmpty)
                      _chip(
                          Icons.account_balance_rounded, pString('university')),
                    if (pString('college').isNotEmpty)
                      _chip(Icons.school_rounded, pString('college')),
                    if (pString('department').isNotEmpty)
                      _chip(Icons.menu_book_rounded, pString('department')),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickDashboard(bool ar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _metric(ar ? 'منشورات' : 'Posts', '${_posts.length}',
                  Icons.article_outlined),
              _metric(ar ? 'متابعون' : 'Followers', '$_followers',
                  Icons.people_alt_outlined),
              _metric(ar ? 'يتابع' : 'Following', '$_followingCount',
                  Icons.person_outline_rounded),
              _metric(ar ? 'إعجابات' : 'Likes', '$_likesReceived',
                  Icons.favorite_border_rounded),
            ]),
            if (isMe) ...[
              const Divider(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 12,
                children: [
                  if (FeatureControl.instance.visible('activity_stats'))
                    _shortcut(Icons.insights_rounded,
                        ar ? 'إحصاءاتي' : 'Insights', _openStats),
                  if (FeatureControl.instance.visible('activity_stats'))
                    _shortcut(Icons.timeline_rounded, ar ? 'نشاطي' : 'Activity',
                        _openActivity),
                  if (FeatureControl.instance.visible('activity_stats'))
                    _shortcut(Icons.emoji_events_rounded,
                        ar ? 'إنجازاتي' : 'Achievements', _openAchievements),
                  if (FeatureControl.instance.visible('saved_posts'))
                    _shortcut(Icons.bookmark_rounded,
                        ar ? 'المحفوظات' : 'Saved', _openSaved),
                  if (FeatureControl.instance.visible('books_market'))
                    _shortcut(Icons.local_library_rounded,
                        ar ? 'مكتبتي' : 'My Library', _openMyLibrary),
                  if (FeatureControl.instance.visible('books_market'))
                    _shortcut(Icons.menu_book_rounded,
                        ar ? 'سوق الكتب' : 'Books', _openBooks),
                  if (FeatureControl.instance.visible('groups'))
                    _shortcut(Icons.groups_rounded, ar ? 'مجموعاتي' : 'Groups',
                        _openGroups),
                  if (FeatureControl.instance.visible('clips'))
                    _shortcut(Icons.video_library_rounded,
                        ar ? 'مقاطع الفيديو' : 'Videos', _openSocial),
                  if (FeatureControl.instance.visible('business_partners'))
                    _shortcut(Icons.business_center_rounded,
                        ar ? 'شركاء Zameel' : 'Zameel Partners', _openBusiness),
                  if (FeatureControl.instance.visible('graduation_book'))
                    _shortcut(Icons.school_rounded,
                        ar ? 'كتاب الخريجين' : 'Alumni Book', _openGraduation),
                ],
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Expanded(
          child: Column(children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant))
      ]));

  Widget _shortcut(IconData icon, String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
              width: 72,
              height: 74,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14)),
                        child: Icon(icon, color: AppTheme.primary)),
                    const SizedBox(height: 5),
                    Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600))
                  ]))));

  Widget _buildEditCard(bool ar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(ar ? 'تخصيص ملفك' : 'Customize your profile',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _field(_name, ar ? 'الاسم الكامل' : 'Full name',
                Icons.person_outline_rounded),
            _field(_username, ar ? 'اسم المستخدم' : 'Username',
                Icons.alternate_email_rounded),
            _field(_headline, ar ? 'العنوان المختصر' : 'Headline',
                Icons.badge_outlined),
            _field(_bio, ar ? 'نبذة عنك' : 'Bio', Icons.notes_rounded,
                maxLines: 3),
            _field(_university, ar ? 'الجامعة' : 'University',
                Icons.account_balance_rounded),
            _field(_college, ar ? 'الكلية' : 'College', Icons.school_outlined),
            _field(_department, ar ? 'التخصص / القسم' : 'Major / Department',
                Icons.menu_book_outlined),
            const SizedBox(height: 4),
            FilledButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save_rounded),
                label: Text(ar ? 'حفظ التغييرات' : 'Save changes')),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
          {int maxLines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: TextField(
              controller: c,
              maxLines: maxLines,
              decoration: InputDecoration(
                  labelText: label, prefixIcon: Icon(icon), filled: true)));

  Widget _buildSectionHeader(bool ar) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        child: Row(children: [
          Text(
              isMe
                  ? (ar ? 'منشوراتي ومشاركاتي' : 'My posts & shares')
                  : (ar ? 'المنشورات العامة' : 'Visible posts'),
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (isMe)
            IconButton.filledTonal(
              onPressed: () => _composePost(ar),
              tooltip: ar ? 'إنشاء منشور' : 'Create post',
              icon: const Icon(Icons.add_rounded),
            ),
          const SizedBox(width: 6),
          Text('${_posts.length + _sharedPosts.length}',
              style: TextStyle(color: AppTheme.adaptiveSecondary)),
        ]),
      );

  Widget _emptyPosts(bool ar) => Padding(
      padding: const EdgeInsets.all(40),
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                Image.asset('assets/branding/zameel_mark.png',
                    width: 70, height: 70),
                const SizedBox(height: 12),
                Text(
                    isMe
                        ? (ar ? 'لم تنشر شيئًا بعد' : 'No posts yet')
                        : (ar
                            ? 'لا توجد منشورات متاحة لك'
                            : 'No posts are visible to you'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(
                    isMe
                        ? (ar
                            ? 'ابدأ بمشاركة شيء مفيد مع زملائك.'
                            : 'Share something useful with your classmates.')
                        : (ar
                            ? 'قد تكون المنشورات خاصة أو مخصصة للزملاء.'
                            : 'Posts may be private or limited to colleagues.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.adaptiveSecondary))
              ]))));

  Widget _postCard(Map<String, dynamic> post, bool ar) {
    final text = (ar ? post['text_ar'] : post['text_en'])?.toString() ?? '';
    final liked = post['liked'] == true;
    final image = post['image_url']?.toString();
    final video = post['video_url']?.toString();
    final hasOrderedMedia = postMediaItems(post).isNotEmpty;
    return CompactPost(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (FeatureControl.instance.enabled('post_promotions') &&
                (_promotionEnds[post['id'].toString()]
                        ?.isAfter(DateTime.now()) ??
                    false))
              Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(ar ? 'إعلان ممول' : 'Sponsored',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600))),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryLight,
                  backgroundImage:
                      (_profile?['profile_image']?.toString().isNotEmpty ==
                              true)
                          ? NetworkImage(_profile!['profile_image'].toString())
                          : null,
                  child: (_profile?['profile_image']?.toString().isNotEmpty ==
                          true)
                      ? null
                      : Image.asset('assets/branding/zameel_mark.png',
                          width: 30, height: 30),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                            child: VerifiedName(
                                userId: widget.userId,
                                child: Text(
                                    _profile?['name']?.toString() ??
                                        (ar ? 'طالب Zameel' : 'Zameel Student'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)))),
                        const SizedBox.shrink()
                      ]),
                      Text(_profile?['university']?.toString() ?? '',
                          style: TextStyle(
                              color: AppTheme.adaptiveSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showPostMenu(post, ar),
                  icon: Icon(Icons.more_horiz_rounded,
                      color: AppTheme.adaptiveSecondary),
                ),
              ],
            ),
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InkWell(
                  onTap: () => _openPost(post),
                  child: CopyableText(text,
                      style: const TextStyle(fontSize: 15, height: 1.55)),
                ),
              ),
            if (hasOrderedMedia)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PostMediaGallery(
                    post: post,
                    height: postMediaHeight(context),
                    onLikeChanged: () {
                      if (mounted) setState(() {});
                    }),
              ),
            if (!hasOrderedMedia && image != null && image.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => _openImage(image),
                    child: SizedBox(
                      height: postMediaHeight(context),
                      child: CachedMediaImage(
                          url: image,
                          fit: BoxFit.contain,
                          fallback: const Center(
                              child: Icon(Icons.broken_image_outlined))),
                    ),
                  ),
                ),
              ),
            if (!hasOrderedMedia && video != null && video.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                      height: postMediaHeight(context),
                      width: double.infinity,
                      child: VideoPlayerWidget(videoUrl: video)),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.favorite_rounded,
                    size: 16,
                    color:
                        liked ? AppTheme.accent : AppTheme.adaptiveSecondary),
                const SizedBox(width: 5),
                InkWell(
                  onTap: () => _showLikes(post, ar),
                  child: Text('${post['likes_count'] ?? 0}',
                      style: TextStyle(
                          color: AppTheme.adaptiveSecondary,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 15),
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 16, color: AppTheme.adaptiveSecondary),
                const SizedBox(width: 5),
                Text('${post['comments_count'] ?? 0}',
                    style: TextStyle(color: AppTheme.adaptiveSecondary)),
                const SizedBox(width: 15),
                Icon(Icons.repeat_rounded,
                    size: 16, color: AppTheme.adaptiveSecondary),
                const SizedBox(width: 5),
                Text('${post['shares_count'] ?? 0}',
                    style: TextStyle(color: AppTheme.adaptiveSecondary)),
                const Spacer(),
                Text(_formatDate(post['created_at']),
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.adaptiveSecondary)),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                    child: _postAction(Icons.favorite_border_rounded,
                        ar ? 'إعجاب' : 'Like', liked, () => _toggleLike(post))),
                if (FeatureControl.instance.visible('comments'))
                  Expanded(
                      child: _postAction(
                          Icons.chat_bubble_outline_rounded,
                          ar ? 'تعليق' : 'Comment',
                          false,
                          () => _openPost(post))),
                if (FeatureControl.instance.visible('saved_posts'))
                  Expanded(
                      child: _postAction(Icons.bookmark_border_rounded,
                          ar ? 'حفظ' : 'Save', false, () => _save(post))),
                Expanded(
                    child: _postAction(Icons.share_outlined,
                        ar ? 'مشاركة' : 'Share', false, () => _share(post))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _postAction(
          IconData icon, String label, bool active, VoidCallback onTap) =>
      InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Icon(active ? Icons.favorite_rounded : icon,
                    size: 20,
                    color:
                        active ? AppTheme.accent : AppTheme.adaptiveSecondary),
                const SizedBox(height: 3),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: active
                            ? AppTheme.accent
                            : AppTheme.adaptiveSecondary))
              ])));

  void _openPost(Map<String, dynamic> post) => FeatureControl.instance
      .open(context, 'comments', () => CommentsScreen(post: post));

  bool _ownsPost(Map<String, dynamic> post) =>
      post['user_id']?.toString() ==
      Supabase.instance.client.auth.currentUser?.id;

  void _openImage(String imageUrl) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
                backgroundColor: Colors.black, foregroundColor: Colors.white),
            body: Center(
              child: InteractiveViewer(
                minScale: .8,
                maxScale: 5,
                child: CachedMediaImage(
                    url: imageUrl,
                    fit: BoxFit.contain,
                    fallback:
                        Icon(Icons.broken_image_outlined, color: Colors.white)),
              ),
            ),
          ),
        ),
      );

  Future<void> _requestPromotion(Map<String, dynamic> post, bool ar) async {
    if (!await FeatureControl.instance.check(context, 'post_promotions') ||
        !mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PromotionRequestScreen(
                postId: post['id'].toString(), arabic: ar)));
  }

  void _showPostMenu(Map<String, dynamic> post, bool ar) {
    final ownsPost = _ownsPost(post);
    showModalBottomSheet(
        context: context,
        builder: (sheetContext) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.open_in_full_rounded),
                  title: Text(ar ? 'فتح المنشور' : 'Open post'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openPost(post);
                  }),
              ListTile(
                  leading: const Icon(Icons.bookmark_add_outlined),
                  title: Text(ar ? 'حفظ المنشور' : 'Save post'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _save(post);
                  }),
              ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: Text(ar ? 'مشاركة المنشور' : 'Share post'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _share(post);
                  }),
              if (!ownsPost)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(ar ? 'الإبلاغ عن المنشور' : 'Report post'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showPostReportDialog(context, post['id'].toString(), ar);
                  },
                ),
              if (ownsPost &&
                  (post['audience'] ?? 'public') == 'public' &&
                  FeatureControl.instance.visible('post_promotions'))
                ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(ar ? 'ترويج المنشور' : 'Promote post'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _requestPromotion(post, ar);
                  },
                ),
              if (ownsPost)
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text(
                      ar ? 'تعديل خصوصية المنشور' : 'Change post visibility'),
                  subtitle: Text(_audienceLabel(
                      post['audience']?.toString() ?? 'public', ar)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _choosePostAudience(post, ar);
                  },
                ),
              if (ownsPost && post['audience'] != 'private')
                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: Text(
                      ar ? 'إخفاء المنشور — أنا فقط' : 'Hide post — only me'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await PostPublishService.updateAudience(
                          post['id'].toString(), 'private');
                      if (mounted) setState(() => post['audience'] = 'private');
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                '${ar ? 'تعذر إخفاء المنشور' : 'Could not hide post'}: $e')));
                    }
                  },
                ),
              if (ownsPost)
                ListTile(
                    leading: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red),
                    title: Text(ar ? 'حذف المنشور' : 'Delete post'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await PostPublishService.deletePost(
                          post['id'].toString());
                      _load();
                    }),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar
              ? 'تم تحديث خصوصية المنشور في جميع الصفحات.'
              : 'Post visibility updated everywhere.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${ar ? 'تعذر تحديث الخصوصية' : 'Could not update visibility'}: $e')));
    }
  }

  Future<void> _composePost(bool ar) async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
              leading: const Icon(Icons.collections_rounded),
              title: Text(ar ? 'منشور متعدد الوسائط' : 'Multi-media post'),
              subtitle: Text(ar
                  ? 'نص + عدة صور + عدة فيديوهات'
                  : 'Text + multiple photos + multiple videos'),
              onTap: () => Navigator.pop(ctx, 'rich')),
          ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: Text(ar ? 'منشور نصي' : 'Text post'),
              onTap: () => Navigator.pop(ctx, 'text')),
          ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(ar ? 'منشور بصورة' : 'Photo post'),
              onTap: () => Navigator.pop(ctx, 'image')),
          ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: Text(ar ? 'منشور فيديو' : 'Video post'),
              onTap: () => Navigator.pop(ctx, 'video')),
          ListTile(
              leading: const Icon(Icons.auto_awesome_motion_outlined),
              title: Text(ar ? 'إضافة حالة' : 'Add story'),
              onTap: () => Navigator.pop(ctx, 'story')),
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
                      hintText: ar
                          ? 'اكتب نصًا اختياريًا...'
                          : 'Write optional text...',
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
                      onPressed: selectedMedia.length >=
                              PostPublishService.maxMediaItems
                          ? null
                          : () async {
                              final result =
                                  await PostPublishService.pickMultipleMedia(
                                limit: PostPublishService.maxMediaItems -
                                    selectedMedia.length,
                              );
                              if (result.isEmpty) return;

                              final existing = selectedMedia
                                  .map((file) => '${file.name}:${file.path}')
                                  .toSet();
                              for (final file in result) {
                                if (!PostPublishService.isSupportedFile(file))
                                  continue;
                                final key = '${file.name}:${file.path}';
                                if (!existing.add(key)) continue;
                                if (selectedMedia.length >=
                                    PostPublishService.maxMediaItems) break;
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
                          color:
                              video ? AppTheme.primaryDark : AppTheme.primary,
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
                if (controller.text.trim().isEmpty && selectedMedia.isEmpty)
                  return;
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
          SnackBar(
              content: Text('${ar ? 'تعذر النشر' : 'Could not publish'}: $e')),
        );
      }
    }
  }

  Future<String?> _newAudience(bool ar) async {
    var audience = _profile?['default_post_audience']?.toString() ?? 'public';
    return showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (_, setLocal) => AlertDialog(
                  title: Text(
                      ar ? 'من يمكنه مشاهدة المحتوى؟' : 'Who can see this?'),
                  content: DropdownButtonFormField<String>(
                      value: audience,
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                      items: const ['public', 'friends', 'private']
                          .map((v) => DropdownMenuItem(
                              value: v, child: Text(_audienceLabel(v, ar))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => audience = v);
                      }),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(ar ? 'إلغاء' : 'Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, audience),
                        child: Text(ar ? 'متابعة' : 'Continue'))
                  ],
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
                hintText:
                    ar ? 'أضف وصفًا اختياريًا' : 'Add an optional caption',
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
          SnackBar(
              content: Text('${ar ? 'تعذر النشر' : 'Could not publish'}: $e')),
        );
      }
    }
  }

  Future<void> _composeProfileStory(bool ar) async {
    final type = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.image),
                  title: Text(ar ? 'حالة بصورة' : 'Photo story'),
                  onTap: () => Navigator.pop(ctx, 'image')),
              ListTile(
                  leading: const Icon(Icons.videocam),
                  title: Text(ar ? 'حالة فيديو' : 'Video story'),
                  onTap: () => Navigator.pop(ctx, 'video'))
            ])));
    if (type == null) return;
    final file = type == 'video'
        ? await _picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 60))
        : await _picker.pickImage(
            source: ImageSource.gallery, imageQuality: 88);
    if (file == null) return;
    final audience = await _newAudience(ar);
    if (audience == null) return;
    try {
      final id = await ZameelSocialService.createStoryFile(
          file: file, mediaType: type, caption: '', audience: audience);
      if (id == null) throw Exception('upload_failed');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ar ? 'تم نشر الحالة ✓' : 'Story published ✓')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${ar ? 'تعذر نشر الحالة' : 'Could not publish story'}: $e')));
    }
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
            TextField(
                controller: controller,
                autofocus: true,
                maxLines: 5,
                decoration: InputDecoration(
                    hintText: ar ? 'بماذا تفكر؟' : "What's on your mind?",
                    border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: audience,
              decoration: InputDecoration(
                  labelText: ar ? 'الخصوصية' : 'Visibility',
                  border: const OutlineInputBorder()),
              items: const ['public', 'friends', 'private']
                  .map((v) => DropdownMenuItem(
                      value: v, child: Text(_audienceLabel(v, ar))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => audience = v);
              },
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(ar ? 'إلغاء' : 'Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(ar ? 'نشر' : 'Publish')),
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
      await Supabase.instance.client.from('posts').insert({
        'user_id': me.id,
        'type': 'text',
        'text_ar': text,
        'text_en': text,
        'audience': audience
      });
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${ar ? 'تعذر نشر المنشور' : 'Could not publish'}: $e')));
    }
  }

  Future<void> _showLikes(Map<String, dynamic> post, bool ar) async {
    final postId = post['id'];
    if (postId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('likes')
          .select('user_id, created_at, users(name, profile_image)')
          .eq('post_id', postId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => Directionality(
          textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
          child: SizedBox(
            height: 480,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      ar
                          ? 'الأشخاص الذين أعجبوا بالمنشور'
                          : 'People who liked this post',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800))),
              Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child:
                              Text(ar ? 'لا توجد إعجابات بعد' : 'No likes yet'))
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (_, i) {
                            final u = rows[i]['users'];
                            final name = u is Map
                                ? (u['name']?.toString() ?? 'User')
                                : 'User';
                            final image = u is Map
                                ? u['profile_image']?.toString()
                                : null;
                            return ListTile(
                                leading: CircleAvatar(
                                    backgroundImage:
                                        image != null && image.isNotEmpty
                                            ? NetworkImage(image)
                                            : null,
                                    child: image == null || image.isEmpty
                                        ? const Icon(Icons.person)
                                        : null),
                                title: VerifiedName(
                                    userId: rows[i]['user_id']?.toString(),
                                    child: Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700))));
                          }))
            ]),
          ),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تحميل قائمة الإعجابات: $e')));
    }
  }

  Future<void> _save(Map<String, dynamic> post) async {
    if (!await FeatureControl.instance.check(context, 'saved_posts')) return;
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null || post['id'] == null) return;
    try {
      await Supabase.instance.client
          .from('saved_posts')
          .upsert({'user_id': me.id, 'post_id': post['id']});
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم حفظ المنشور ✓')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(FeatureControl.errorMessage(e, 'تعذر الحفظ'))));
    }
  }

  Future<void> _share(Map<String, dynamic> post) async {
    final me = Supabase.instance.client.auth.currentUser;
    final postId = post['id'];
    if (me == null || postId == null) return;
    try {
      await Supabase.instance.client
          .from('shared_posts')
          .upsert({'post_id': postId, 'shared_by': me.id});
      final text = (post['text_ar'] ?? post['text_en'] ?? '').toString();
      await Clipboard.setData(ClipboardData(text: text));
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت مشاركة المنشور في ملفك ✓')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر مشاركة المنشور: $e')));
    }
  }

  Future<void> _unshare(Map<String, dynamic> post) async {
    final me = Supabase.instance.client.auth.currentUser;
    final postId = post['id'];
    if (me == null || postId == null) return;
    try {
      await Supabase.instance.client
          .from('shared_posts')
          .delete()
          .eq('post_id', postId)
          .eq('shared_by', me.id);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم إلغاء المشاركة ✓')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر إلغاء المشاركة: $e')));
    }
  }

  Widget _sharedPostCard(Map<String, dynamic> post, bool ar) {
    return Material(
      color: Colors.transparent,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
          child: Row(children: [
            const Icon(Icons.repeat_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 7),
            Expanded(
                child: Text(
                    ar
                        ? 'منشور تمت مشاركته في ملفك'
                        : 'Post shared to your profile',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark))),
            if (isMe)
              IconButton(
                  onPressed: () => _unshare(post),
                  icon: const Icon(Icons.undo_rounded),
                  tooltip: ar ? 'إلغاء المشاركة' : 'Unshare'),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: _postCard(post, ar)),
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
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(width: 5),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    try {
      final d = DateTime.parse(value.toString());
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inHours < 1) return 'منذ ${diff.inMinutes} د';
      if (diff.inDays < 1) return 'منذ ${diff.inHours} س';
      return 'منذ ${diff.inDays} ي';
    } catch (_) {
      return '';
    }
  }

  void _openActivity() => FeatureControl.instance.open(
      context,
      'activity_stats',
      () => ProfileActivityScreen(
          posts: _posts,
          ar: Provider.of<LanguageProvider>(context, listen: false).isArabic));
  void _openAchievements() => FeatureControl.instance.open(
      context,
      'activity_stats',
      () => ProfileAchievementsScreen(
          posts: _posts.length,
          likes: _likesReceived,
          followers: _followers,
          clips: _clips,
          ar: Provider.of<LanguageProvider>(context, listen: false).isArabic));
  void _openStats() => FeatureControl.instance.open(
      context,
      'activity_stats',
      () => StatsScreen(
          postsCount: _posts.length,
          likesCount: _likesReceived,
          commentsCount: _comments,
          friendsCount: _followers,
          savedBooksCount: _saved,
          activeDays: 0));
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
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => FeatureControl.instance
                  .page('saved_posts', SavedPostsScreen(savedPosts: saved))));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(FeatureControl.errorMessage(e, 'تعذر فتح المحفوظات'))));
    }
  }

  void _openBooks() => FeatureControl.instance
      .open(context, 'books_market', () => const BooksScreen());
  void _openMyLibrary() => FeatureControl.instance
      .open(context, 'books_market', () => const MyLibraryScreen());
  void _openGroups() => FeatureControl.instance
      .open(context, 'groups', () => const GroupsScreen());
  void _openSocial() => FeatureControl.instance.open(
      context,
      'clips',
      () => ZameelSocialStudio(
          isArabic:
              Provider.of<LanguageProvider>(context, listen: false).isArabic));
  void _openBusiness() => FeatureControl.instance
      .open(context, 'business_partners', () => const BusinessScreen());
  void _openGraduation() => FeatureControl.instance.open(
      context,
      'graduation_book',
      () => GraduationBookScreen(
          ownerId: _profile?['id']?.toString() ??
              Supabase.instance.client.auth.currentUser?.id,
          studentName:
              pString('name').isEmpty ? 'طالب Zameel' : pString('name'),
          university: pString('university'),
          major: pString('department'),
          graduationYear: DateTime.now().year.toString()));

  void _showMore() {
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final targetName = pString('name').isEmpty
        ? (ar ? 'هذا المستخدم' : 'this user')
        : pString('name');
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.local_library_rounded),
                title: Text(ar ? 'مكتبتي' : 'My Library'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openMyLibrary();
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: Text(ar ? 'مشاركة الملف' : 'Share profile'),
              onTap: () {
                Navigator.pop(sheetContext);
                Clipboard.setData(ClipboardData(text: targetName));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ اسم الملف للمشاركة')));
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
                leading: const Icon(Icons.person_remove_alt_1_rounded,
                    color: Colors.orange),
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
  const ProfileActivityScreen(
      {super.key, required this.posts, required this.ar});

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final items = <Map<String, dynamic>>[];
    for (final post in posts.take(20)) {
      items.add({
        'icon': post['type'] == 'image'
            ? Icons.photo_rounded
            : Icons.article_rounded,
        'title': ar ? 'نشرت منشورًا جديدًا' : 'Published a new post',
        'subtitle': (ar ? post['text_ar'] : post['text_en'])?.toString() ?? '',
      });
    }
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'نشاطي' : 'My Activity')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: items.isEmpty
            ? Center(child: Text(ar ? 'لا يوجد نشاط بعد.' : 'No activity yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => Card(
                    child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryLight,
                            child: Icon(items[i]['icon'],
                                color: AppTheme.primaryDark)),
                        title: Text(items[i]['title'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(items[i]['subtitle'],
                            maxLines: 2, overflow: TextOverflow.ellipsis))),
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
  const ProfileAchievementsScreen(
      {super.key,
      required this.posts,
      required this.likes,
      required this.followers,
      required this.clips,
      required this.ar});

  @override
  Widget build(BuildContext context) {
    AppearanceScope.observe(context);
    final achievements = [
      (
        ar ? 'أول منشور' : 'First post',
        ar
            ? 'انضممت إلى مجتمع Zameel وشاركت أول منشور.'
            : 'You shared your first Zameel post.',
        posts >= 1,
        Icons.edit_note_rounded
      ),
      (
        ar ? 'صوت المجتمع' : 'Community voice',
        ar ? 'حصلت منشوراتك على 10 إعجابات.' : 'Your posts received 10 likes.',
        likes >= 10,
        Icons.favorite_rounded
      ),
      (
        ar ? 'زميل مؤثر' : 'Community builder',
        ar ? 'وصلت إلى 25 متابعًا.' : 'You reached 25 followers.',
        followers >= 25,
        Icons.people_alt_rounded
      ),
      (
        ar ? 'صانع المقاطع' : 'Clip creator',
        ar
            ? 'أنشأت أول مقطع في مجتمع الزملاء.'
            : 'You created your first community clip.',
        clips >= 1,
        Icons.movie_creation_rounded
      ),
    ];
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'إنجازاتي' : 'Achievements')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: achievements.length,
          separatorBuilder: (_, __) => const SizedBox(height: 9),
          itemBuilder: (_, i) {
            final a = achievements[i];
            final unlocked = a.$3 as bool;
            return Card(
                child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: unlocked
                            ? AppTheme.primaryLight
                            : AppTheme.adaptiveSurfaceAlt,
                        child: Icon(a.$4 as IconData,
                            color: unlocked
                                ? AppTheme.primaryDark
                                : AppTheme.adaptiveSecondary)),
                    title: Text(a.$1 as String,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(a.$2 as String),
                    trailing: Icon(
                        unlocked
                            ? Icons.check_circle_rounded
                            : Icons.lock_outline_rounded,
                        color: unlocked
                            ? Colors.green
                            : AppTheme.adaptiveSecondary)));
          },
        ),
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();
  @override
  Widget build(BuildContext context) => AppearanceScope.rebuild(context,
      () => const Scaffold(body: Center(child: CircularProgressIndicator())));
}

class _NotFound extends StatelessWidget {
  final bool ar;
  const _NotFound({required this.ar});
  @override
  Widget build(BuildContext context) => AppearanceScope.rebuild(
      context,
      () => Scaffold(
          appBar: AppBar(),
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/branding/zameel_mark.png',
                width: 80, height: 80),
            const SizedBox(height: 12),
            Text(ar ? 'المستخدم غير موجود' : 'User not found',
                style: const TextStyle(fontWeight: FontWeight.bold))
          ]))));
}
