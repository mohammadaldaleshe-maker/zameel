part of '../main.dart';

class HomeFeedScreen extends StatefulWidget {
  final University university;
  final College college;
  final String department;

  const HomeFeedScreen({
    super.key,
    required this.university,
    required this.college,
    required this.department,
  });

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> with WidgetsBindingObserver {
  int currentIndex = 0;
  File? profileImage;
  Uint8List? profileImageBytes;
  String? profileImageUrl;
  String? profileName;
  final ImagePicker picker = ImagePicker();
  bool isAdmin = false;
  List<Map<String, dynamic>> savedPosts = [];
  List<Map<String, dynamic>> posts = [];
  bool _isLoading = true;
  String _postAudience = 'public';
  int _unreadNotifications = 0;
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _postsChannel;
  Timer? _notificationReloadDebounce;
  Timer? _feedReloadDebounce;
  Timer? _feedRefreshTimer;
  bool _incomingCallDialogOpen = false;
  final Set<String> _handledIncomingCalls = <String>{};
  String _feedScope = 'global';
  final ScrollController _feedScrollController = ScrollController();
  Offset? _arcMenuPosition;

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _createUserIfNotExists();
  _loadCurrentProfileImage();
  _loadPosts();
  _loadUnreadNotifications();
  _subscribeToNotifications();
  _subscribeToFeedUpdates();
  _feedRefreshTimer = Timer.periodic(
    const Duration(seconds: 30),
    (_) => _loadPosts(silent: true),
  );
  _loadArcMenuPosition();
  _loadFeedScope();
}

Future<void> _loadFeedScope() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('zameel_feed_scope');
  if (mounted && <String>{'global', 'college', 'department'}.contains(saved)) {
    setState(() => _feedScope = saved!);
  }
}

Future<void> _setFeedScope(String scope) async {
  if (!<String>{'global', 'college', 'department'}.contains(scope)) return;
  setState(() => _feedScope = scope);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('zameel_feed_scope', scope);
}

List<Map<String, dynamic>> get _visiblePosts {
  if (_feedScope == 'global') return posts;
  final university = widget.university.name.trim().toLowerCase();
  final college = widget.college.name.trim().toLowerCase();
  final department = widget.department.trim().toLowerCase();
  return posts.where((post) {
    final user = post['users'] is Map ? post['users'] as Map : const <String, dynamic>{};
    final postUniversity = user['university']?.toString().trim().toLowerCase() ?? '';
    final postCollege = user['college']?.toString().trim().toLowerCase() ?? '';
    final postDepartment = user['department']?.toString().trim().toLowerCase() ?? '';
    final sameCollege = university.isNotEmpty && college.isNotEmpty && postUniversity == university && postCollege == college;
    if (_feedScope == 'college') return sameCollege;
    return sameCollege && department.isNotEmpty && postDepartment == department;
  }).toList();
}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationReloadDebounce?.cancel();
    _notificationsChannel?.unsubscribe();
    _feedReloadDebounce?.cancel();
    _feedRefreshTimer?.cancel();
    _postsChannel?.unsubscribe();
    _feedScrollController.dispose();
    super.dispose();
  }

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _loadPosts(silent: true);
    _loadUnreadNotifications();
  }
}

Future<void> _loadArcMenuPosition() async {
  final prefs = await SharedPreferences.getInstance();
  final x = prefs.getDouble('zameel_arc_menu_x');
  final y = prefs.getDouble('zameel_arc_menu_y');
  if (!mounted || x == null || y == null) return;
  final size = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  final maxX = (size.width - 250).clamp(0.0, double.infinity);
  final maxY = (size.height - padding.bottom - 70).clamp(padding.top + 4, double.infinity);
  setState(() => _arcMenuPosition = Offset(x.clamp(0.0, maxX), y.clamp(padding.top + 4, maxY)));
}

void _subscribeToFeedUpdates() {
  final client = Supabase.instance.client;
  _postsChannel = client.channel('zameel-home-feed-live');
  _postsChannel!
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'posts',
        callback: (_) {
          _feedReloadDebounce?.cancel();
          _feedReloadDebounce = Timer(
            const Duration(milliseconds: 350),
            () => _loadPosts(silent: true),
          );
        },
      )
      .subscribe();
}

void _moveArcMenu(Offset delta) {
  final size = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
  final current = _arcMenuPosition ?? Offset(isArabic ? 12 : size.width - 262, padding.top + 10);
  final maxX = (size.width - 250).clamp(0.0, double.infinity);
  final maxY = (size.height - padding.bottom - 70).clamp(padding.top + 4, double.infinity);
  final next = Offset((current.dx + delta.dx).clamp(0.0, maxX), (current.dy + delta.dy).clamp(padding.top + 4, maxY));
  setState(() => _arcMenuPosition = next);
  SharedPreferences.getInstance().then((prefs) {
    prefs.setDouble('zameel_arc_menu_x', next.dx);
    prefs.setDouble('zameel_arc_menu_y', next.dy);
  });
}

String _calendarKey() {
  final n = widget.university.name.toLowerCase();
  if (n.contains('يرموك') || n.contains('yarmouk')) return 'yu';
  if (n.contains('علوم') || n.contains('science and technology') || n.contains('just')) return 'just';
  if (n.contains('هاشمية') || n.contains('hashemite')) return 'hu';
  return 'ju';
}

Future<void> _loadUnreadNotifications() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  try {
    final rows = await Supabase.instance.client.from('notifications').select('id').eq('user_id', user.id).eq('is_read', false);
    if (mounted) setState(() => _unreadNotifications = rows.length);
  } catch (_) {}
}

void _subscribeToNotifications() {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;
  _notificationsChannel = client.channel('zameel-home-notifications:${user.id}');
  _notificationsChannel!
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) {
          _notificationReloadDebounce?.cancel();
          _notificationReloadDebounce = Timer(
            const Duration(milliseconds: 180),
            _loadUnreadNotifications,
          );
          final row = Map<String, dynamic>.from(payload.newRecord);
          final type = row['type']?.toString() ?? '';
          if (type == 'incoming_video_call' ||
              type == 'incoming_voice_call') {
            Future.microtask(() => _handleIncomingCallNotification(row));
          }
        },
      )
      .subscribe();
}

Map<String, dynamic> _notificationData(Map<String, dynamic> n) {
  final raw = n['data'];
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

Future<void> _handleIncomingCallNotification(Map<String, dynamic> n) async {
  if (!mounted || _incomingCallDialogOpen) return;
  final notificationId = n['id']?.toString() ?? '';
  if (notificationId.isEmpty || _handledIncomingCalls.contains(notificationId)) {
    return;
  }

  final data = _notificationData(n);
  final roomId = data['room_id']?.toString() ?? '';
  if (roomId.isEmpty) return;

  _handledIncomingCalls.add(notificationId);
  _incomingCallDialogOpen = true;

  final type = n['type']?.toString() ?? '';
  final video = data['video'] == true ||
      data['video']?.toString().toLowerCase() == 'true' ||
      type == 'incoming_video_call';
  final actorId = n['actor_id']?.toString();
  String callerName = 'Colleague';
  if (actorId != null && actorId.isNotEmpty) {
    try {
      final actor = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('id', actorId)
          .maybeSingle();
      final name = actor?['name']?.toString().trim();
      if (name != null && name.isNotEmpty) callerName = name;
    } catch (_) {}
  }

  if (!mounted) {
    _incomingCallDialogOpen = false;
    return;
  }

  final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        video
            ? (ar ? 'مكالمة فيديو واردة' : 'Incoming video call')
            : (ar ? 'مكالمة صوتية واردة' : 'Incoming voice call'),
      ),
      content: Text(
        ar ? '$callerName يتصل بك الآن' : '$callerName is calling you',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(ar ? 'رفض' : 'Decline'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: Icon(video ? Icons.videocam_rounded : Icons.call_rounded),
          label: Text(ar ? 'رد' : 'Answer'),
        ),
      ],
    ),
  );
  _incomingCallDialogOpen = false;

  try {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  } catch (_) {}

  if (accepted != true || !mounted) return;
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => MeetScreen(
        participantName: callerName,
        roomId: roomId,
        startImmediately: true,
        startWithVideo: video,
        isInitiator: false,
      ),
    ),
  );
}

Future<void> _loadCurrentProfileImage() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  try {
    final row = await Supabase.instance.client
        .from('users')
        .select('name,profile_image')
        .eq('id', user.id)
        .maybeSingle();
    final url = row?['profile_image']?.toString();
    final metadataName = user.userMetadata?['name']?.toString();
    final dbName = row?['name']?.toString();
    if (!mounted) return;
    setState(() {
      profileImageUrl = (url == null || url.isEmpty) ? null : url;
      profileName = (dbName != null && dbName.trim().isNotEmpty)
          ? dbName.trim()
          : ((metadataName != null && metadataName.trim().isNotEmpty)
              ? metadataName.trim()
              : 'مستخدم');
    });
  } catch (_) {}
}

  // ============================================================
  // جلب المنشورات من Supabase
  // ============================================================

 Future<void> _loadPosts({bool silent = false}) async {
  if (!silent && mounted) setState(() => _isLoading = true);
  try {
    final db = Supabase.instance.client;
    final response = await db
        .from('posts')
        .select('*, users(name, profile_image, gender, role, university, college, department)')
        .order('created_at', ascending: false);

    // Production feed: use only posts that actually exist in Supabase.
    // Demo posts use synthetic IDs and cannot participate in DB-backed
    // features such as comments, likes, saves, or sharing.
    final loaded = List<Map<String, dynamic>>.from(response);
    final user = db.auth.currentUser;

    if (user != null && loaded.isNotEmpty) {
      try {
        final likes = await db
            .from('likes')
            .select('post_id')
            .eq('user_id', user.id);
        final likedIds = likes.map((r) => r['post_id'].toString()).toSet();

        final saved = await db
            .from('saved_posts')
            .select('post_id')
            .eq('user_id', user.id);
        final savedIds = saved.map((r) => r['post_id'].toString()).toSet();

        for (final post in loaded) {
          final id = post['id']?.toString();
          post['liked'] = id != null && likedIds.contains(id);
          post['isSaved'] = id != null && savedIds.contains(id);
          post['shares'] = (post['shares_count'] ?? 0);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      posts = _diversifyFeed(loaded);
      _isLoading = false;
    });
  } catch (e) {
    debugPrint('Error loading posts: $e');
    if (mounted && !silent) setState(() => _isLoading = false);
  }
}

List<Map<String, dynamic>> _diversifyFeed(
    List<Map<String, dynamic>> source) {
  final women = <Map<String, dynamic>>[];
  final men = <Map<String, dynamic>>[];
  final business = <Map<String, dynamic>>[];
  final other = <Map<String, dynamic>>[];

  for (final post in source) {
    final owner = post['users'];
    final role = owner is Map
        ? owner['role']?.toString().toLowerCase()
        : null;
    final gender = owner is Map
        ? owner['gender']?.toString().toLowerCase()
        : null;

    final businessRoles = <String>{'business','company','merchant','store','organization','نشاط تجاري','شركة','مؤسسة'};
    final femaleValues = <String>{'female','woman','women','أنثى','انثى'};
    final maleValues = <String>{'male','man','men','ذكر'};
    if (businessRoles.contains(role)) {
      business.add(post);
    } else if (femaleValues.contains(gender)) {
      women.add(post);
    } else if (maleValues.contains(gender)) {
      men.add(post);
    } else {
      other.add(post);
    }
  }

  final result = <Map<String, dynamic>>[];
  var wi = 0;
  var mi = 0;
  var bi = 0;
  var oi = 0;

  void addIfAvailable(List<Map<String, dynamic>> list, int index) {
    if (index < list.length) result.add(list[index]);
  }

  while (result.length < source.length) {
    for (var i = 0; i < 3 && result.length < source.length; i++) {
      if (wi < women.length) {
        addIfAvailable(women, wi++);
      }
    }

    if (result.length < source.length && mi < men.length) {
      addIfAvailable(men, mi++);
    }

    if (result.length < source.length && bi < business.length) {
      addIfAvailable(business, bi++);
    }

    // Unknown/other is used to keep the feed full without inventing
    // gender or business classification.
    if (result.length < source.length && oi < other.length) {
      addIfAvailable(other, oi++);
    }

    if (wi >= women.length &&
        mi >= men.length &&
        bi >= business.length &&
        oi >= other.length) {
      break;
    }

    // If a requested bucket is exhausted, continue from the remaining
    // buckets so no eligible post is silently discarded.
    if (result.length < source.length &&
        wi >= women.length &&
        oi >= other.length) {
      while (mi < men.length) addIfAvailable(men, mi++);
      while (bi < business.length) addIfAvailable(business, bi++);
    }
    if (result.length < source.length &&
        mi >= men.length &&
        oi >= other.length) {
      while (wi < women.length) addIfAvailable(women, wi++);
      while (bi < business.length) addIfAvailable(business, bi++);
    }
    if (result.length < source.length &&
        bi >= business.length &&
        oi >= other.length) {
      while (wi < women.length) addIfAvailable(women, wi++);
      while (mi < men.length) addIfAvailable(men, mi++);
    }
  }

  return result;
}

Future<void> _createUserIfNotExists() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
        .from('users')
        .select('id,name,university,college,department,profile_image,account_privacy,default_post_audience,allow_messages,allow_calls,notifications_enabled,gender,role,created_at,updated_at')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      final newUser = {
        'id': user.id,
        'name': user.userMetadata?['name'] ?? 'مستخدم',
        'email': user.email,
        'university': '',
        'college': '',
        'department': '',
        'profile_image': null,
        'account_privacy': 'public',
        'default_post_audience': 'public',
        'allow_messages': true,
        'allow_calls': true,
        'notifications_enabled': true,
        'gender': null,
        'created_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client
          .from('users')
          .insert(newUser);

      print('✅ تم إنشاء المستخدم في قاعدة البيانات');
    } else {
      final audience = response['default_post_audience']?.toString();
      if (audience == 'public' || audience == 'friends' || audience == 'private') {
        _postAudience = audience!;
      }
      print('✅ المستخدم موجود بالفعل');
    }
  } catch (e) {
    print('❌ خطأ في إنشاء المستخدم: $e');
  }
}

  // ============================================================
  // إنشاء منشور جديد في Supabase
  // ============================================================

  Future<void> _createPost(String text, {String? audience}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ الرجاء تسجيل الدخول',
            ),
          ),
        );
        return;
      }

      final newPost = {
        'user_id': user.id,
        'type': 'text',
        'text_ar': text,
        'text_en': text,
        'likes_count': 0,
        'comments_count': 0,
        'audience': audience ?? _postAudience,
      };

      final response = await Supabase.instance.client
          .from('posts')
          .insert(newPost)
          .select()
          .single();

      if (response != null) {
        setState(() {
          posts.insert(0, {
            ...response,
            'users': {
              'name': user.userMetadata?['name'] ?? 'مستخدم',
              'email': user.email,
            },
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم نشر المنشور!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل النشر: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // حذف المنشور (مع صلاحيات)
  // ============================================================

  Future<void> _deletePost(Map<String, dynamic> post) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ الرجاء تسجيل الدخول'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // التحقق من الصلاحية: المدير أو صاحب المنشور
      final isOwner = post['user_id'] == user.id;
      final isAdminUser = isAdmin;

      if (!isOwner && !isAdminUser) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ ليس لديك صلاحية لحذف هذا المنشور'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // حذف المنشور من قاعدة البيانات
      await Supabase.instance.client
          .from('posts')
          .delete()
          .eq('id', post['id']);

      // حذف المنشور من القائمة المحلية
      setState(() {
        posts.removeWhere((p) => p['id'] == post['id']);
        savedPosts.removeWhere((p) => p['id'] == post['id']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ تم حذف المنشور بنجاح'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل الحذف: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // نافذة تأكيد الحذف (مع إظهار اسم صاحب المنشور)
  // ============================================================

  void _showDeleteConfirmation(
    BuildContext context,
    Map<String, dynamic> post,
  ) {
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final user = Supabase.instance.client.auth.currentUser;
    final isOwner = post['user_id'] == user?.id;
    final isAdminUser = isAdmin;

    // إذا كان المستخدم ليس صاحب المنشور وليس مديرًا، لا يعرض زر الحذف
    if (!isOwner && !isAdminUser) {
      return;
    }

    final String ownerName = post['users']?['name'] ?? 'مستخدم';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(
              isArabic ? '🗑️ حذف المنشور' : '🗑️ Delete Post',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              isArabic
                  ? 'هل أنت متأكد من رغبتك في حذف هذا المنشور؟\n\n'
                    '👤 صاحب المنشور: $ownerName'
                  : 'Are you sure you want to delete this post?\n\n'
                    '👤 Post owner: $ownerName',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  isArabic ? 'إلغاء' : 'Cancel',
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _deletePost(post);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isArabic ? 'تأكيد الحذف' : 'Confirm Delete',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // الإعجاب بمنشور
  // ============================================================

  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= posts.length) return;
    final post = posts[index];
    final user = Supabase.instance.client.auth.currentUser;
    final postId = post['id'];
    if (user == null || postId == null) return;

    final wasLiked = post['liked'] == true;
    final oldCount = ((post['likes_count'] ?? 0) as num).toInt();

    // Optimistic UI: the button responds immediately.
    setState(() {
      post['liked'] = !wasLiked;
      post['likes_count'] = wasLiked ? (oldCount > 0 ? oldCount - 1 : 0) : oldCount + 1;
    });

    if (post['is_demo'] == true) return;

    try {
      final db = Supabase.instance.client;
      if (wasLiked) {
        await db.from('likes').delete().eq('user_id', user.id).eq('post_id', postId);
      } else {
        await db.from('likes').upsert({'user_id': user.id, 'post_id': postId});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        post['liked'] = wasLiked;
        post['likes_count'] = oldCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الإعجاب: $e')),
      );
    }
  }

  // ============================================================
  // حفظ منشور
  // ============================================================

  Future<void> _toggleSavePost(int index) async {
    final post = posts[index];
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    try {
      final isSaved = post['isSaved'] ?? false;

      if (isSaved) {
        await Supabase.instance.client
            .from('saved_posts')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', post['id']);

        setState(() {
          posts[index]['isSaved'] = false;
          savedPosts.removeWhere(
            (p) => p['id'] == post['id'],
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ تم إلغاء الحفظ'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        await Supabase.instance.client
            .from('saved_posts')
            .insert({
              'user_id': user.id,
              'post_id': post['id'],
            });

        setState(() {
          posts[index]['isSaved'] = true;
          savedPosts.insert(0, post);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ المنشور'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error toggling save: $e');
    }
  }

  Future<void> pickProfileImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        profileImageBytes = bytes;
        // Keep the File for native platforms; Web uses profileImageBytes.
        profileImage = kIsWeb ? null : File(image.path);
      });
    }
  }

  void toggleLike(int index) {
    _toggleLike(index);
  }

  Future<void> _pickImage() async {
      final audience = await _choosePostAudience();
      if (audience == null) return;
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري رفع الصورة...'),
        ),
      );

      final bytes = await image.readAsBytes();

      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final storagePath = '${user.id}/images/$fileName';

      await Supabase.instance.client.storage
          .from('posts')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$extension',
              upsert: false,
            ),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('posts')
          .getPublicUrl(storagePath);

      final response = await Supabase.instance.client
          .from('posts')
          .insert({
            'user_id': user.id,
            'type': 'image',
            'text_ar': '',
            'text_en': '',
            'image_url': imageUrl,
            'video_url': null,
            'likes_count': 0,
            'comments_count': 0,
            'audience': audience,
          })
          .select()
          .single();

      if (!mounted) return;

      setState(() {
        posts.insert(0, {
          ...response,
          'name_ar': user.userMetadata?['name'] ?? 'مستخدم',
          'name_en': user.userMetadata?['name'] ?? 'User',
          'department_ar': widget.department,
          'department_en': widget.department,
          'likes': 0,
          'comments': 0,
          'liked': false,
          'isSaved': false,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر الصورة بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('IMAGE UPLOAD ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل رفع الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
      final audience = await _choosePostAudience();
      if (audience == null) return;
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري رفع الفيديو...'),
        ),
      );

      final bytes = await video.readAsBytes();

      final extension = video.name.contains('.')
          ? video.name.split('.').last.toLowerCase()
          : 'mp4';

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final storagePath = '${user.id}/videos/$fileName';

      String contentType = 'video/mp4';

      if (extension == 'webm') {
        contentType = 'video/webm';
      } else if (extension == 'mov') {
        contentType = 'video/quicktime';
      } else if (extension == 'm4v') {
        contentType = 'video/x-m4v';
      }

      await Supabase.instance.client.storage
          .from('posts')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );

      final videoUrl = Supabase.instance.client.storage
          .from('posts')
          .getPublicUrl(storagePath);

      final response = await Supabase.instance.client
          .from('posts')
          .insert({
            'user_id': user.id,
            'type': 'video',
            'text_ar': '',
            'text_en': '',
            'image_url': null,
            'video_url': videoUrl,
            'likes_count': 0,
            'comments_count': 0,
            'audience': audience,
          })
          .select()
          .single();

      if (!mounted) return;

      setState(() {
        posts.insert(0, {
          ...response,
          'name_ar': user.userMetadata?['name'] ?? 'مستخدم',
          'name_en': user.userMetadata?['name'] ?? 'User',
          'department_ar': widget.department,
          'department_en': widget.department,
          'likes': 0,
          'comments': 0,
          'liked': false,
          'isSaved': false,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر الفيديو بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('VIDEO UPLOAD ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل رفع الفيديو: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _choosePostAudience() async {
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.public_rounded), title: Text(ar ? 'عامة' : 'Public'), subtitle: Text(ar ? 'يراها جميع مستخدمي Zameel' : 'Visible to all Zameel users'), onTap: () => Navigator.pop(ctx, 'public')),
        ListTile(leading: const Icon(Icons.groups_rounded), title: Text(ar ? 'للزملاء' : 'Colleagues'), subtitle: Text(ar ? 'للأشخاص الذين تتابعهم' : 'Visible to people you follow'), onTap: () => Navigator.pop(ctx, 'friends')),
        ListTile(leading: const Icon(Icons.lock_rounded), title: Text(ar ? 'لي فقط' : 'Only me'), subtitle: Text(ar ? 'خاص بك فقط' : 'Private to you'), onTap: () => Navigator.pop(ctx, 'private')),
      ])),
    );
  }

  void createPost() {
    final controller = TextEditingController();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: languageProvider.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: Colors.white.withAlpha(230),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              Translations.translate(
                'create_post_title',
                languageProvider.currentLanguage,
              ),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              StatefulBuilder(builder: (context, setAudience) => DropdownButtonFormField<String>(
                value: _postAudience,
                decoration: InputDecoration(labelText: languageProvider.isArabic ? 'من يمكنه رؤية المنشور؟' : 'Who can see this post?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: [
                  DropdownMenuItem(value: 'public', child: Text(languageProvider.isArabic ? '🌍 عامة' : '🌍 Public')),
                  DropdownMenuItem(value: 'friends', child: Text(languageProvider.isArabic ? '👥 الزملاء' : '👥 Colleagues')),
                  DropdownMenuItem(value: 'private', child: Text(languageProvider.isArabic ? '🔒 لي فقط' : '🔒 Only me')),
                ],
                onChanged: (v) { if (v != null) { _postAudience = v; setAudience(() {}); } },
              )),
              const SizedBox(height: 10),
              TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                hintText: Translations.translate(
                  'create_post_hint',
                  languageProvider.currentLanguage,
                ),
                filled: true,
                fillColor: AppTheme.muted.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  Translations.translate(
                    'create_post_cancel',
                    languageProvider.currentLanguage,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;

                  Navigator.pop(dialogContext);
                  await _createPost(
                    controller.text.trim(),
                    audience: _postAudience,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  Translations.translate(
                    'create_post_publish',
                    languageProvider.currentLanguage,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradientStart,
              gradientEnd,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/branding/zameel_mark.png',
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Zameel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .4,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        final user = Supabase.instance.client.auth.currentUser;
                        Navigator.pop(context);
                        if (user != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: user.id),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            _ProfileAvatar(image: profileImage, imageBytes: profileImageBytes, imageUrl: profileImageUrl, radius: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profileName ?? (isArabic ? 'مستخدم' : 'User'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(isArabic ? 'الصفحة الشخصية' : 'Profile', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _DrawerItem(
              icon: Icons.home_rounded,
              title: isArabic ? 'الرئيسية' : 'Home',
              onTap: () {
                setState(() {
                  currentIndex = 0;
                });
                Navigator.pop(context);
              },
              isSelected: currentIndex == 0,
            ),
            _DrawerItem(
              icon: Icons.menu_book_rounded,
              title: isArabic ? 'الكتب' : 'Books',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BooksScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.chat_bubble_rounded,
              title: isArabic ? 'الدردشة' : 'Chat',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.people_rounded,
              title: isArabic ? 'زملاء' : 'Colleagues',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FriendsScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.map_rounded,
              title: isArabic ? 'الحرم الجامعي' : 'Campus',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CampusScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.video_call_rounded,
              title: isArabic ? 'اجتمع بالزملاء' : 'Meet',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MeetScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.work_rounded,
              title: isArabic ? 'وظائف' : 'Jobs',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JobsScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.calendar_month_rounded,
              title: isArabic ? 'تقويم' : 'Calendar',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalendarScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.poll_rounded,
              title: isArabic ? 'استطلاعات' : 'Polls',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PollsScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.group_rounded,
              title: isArabic ? 'مجموعات' : 'Groups',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GroupsScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.auto_awesome_rounded,
              title: isArabic ? 'Zameel AI' : 'Zameel AI',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AIScreen(),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.business_center_rounded,
              title: isArabic ? 'شركاء Zameel' : 'Zameel Partners',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BusinessScreen()),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.person_rounded,
              title: isArabic ? 'حسابي' : 'Profile',
              onTap: () {
                setState(() {
                  currentIndex = 11;
                });
                Navigator.pop(context);
              },
              isSelected: currentIndex == 11,
            ),
            const Divider(
              color: Colors.white24,
            ),
            _DrawerItem(
              icon: Icons.delete_forever_rounded,
              title: isArabic ? 'حذف الحساب' : 'Delete account',
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => Directionality(
                    textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                    child: AlertDialog(
                      title: Text(isArabic ? 'حذف الحساب نهائياً؟' : 'Delete account permanently?'),
                      content: Text(isArabic
                          ? 'سيتم حذف حسابك وبياناتك المرتبطة به. لا يمكن التراجع عن هذا الإجراء.'
                          : 'Your account and associated data will be deleted. This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          child: Text(isArabic ? 'حذف الحساب' : 'Delete account'),
                        ),
                      ],
                    ),
                  ),
                );
                if (confirm != true || !mounted) return;
                final deleted = await deleteCurrentAccount();
                if (!mounted) return;
                if (deleted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (_) => false,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isArabic ? 'تعذر حذف الحساب. حاول مرة أخرى.' : 'Could not delete the account. Please try again.')),
                  );
                }
              },
              iconColor: Colors.red,
            ),
            _DrawerItem(
              icon: Icons.logout_rounded,
              title: isArabic ? '🚪 تسجيل الخروج' : '🚪 Logout',
              onTap: () async {
                Navigator.pop(context);

                final confirm = await showDialog(
                  context: context,
                  builder: (dialogContext) {
                    return Directionality(
                      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                      child: AlertDialog(
                        backgroundColor: Colors.white.withAlpha(230),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: Text(
                          isArabic ? 'تسجيل الخروج' : 'Logout',
                        ),
                        content: Text(
                          isArabic
                              ? 'هل أنت متأكد من رغبتك في تسجيل الخروج؟'
                              : 'Are you sure you want to logout?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                                false,
                              );
                            },
                            child: Text(
                              isArabic ? 'إلغاء' : 'Cancel',
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                                true,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              isArabic ? 'تسجيل الخروج' : 'Logout',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );

                if (confirm == true) {
                  await Supabase.instance.client.auth.signOut();

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WelcomeScreen(),
                    ),
                  );
                }
              },
              iconColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: _buildDrawer(context),
        appBar: AppBar(
          backgroundColor: Colors.white, foregroundColor: primaryColor, elevation: 1,
          leading: Builder(builder: (scaffoldContext) => IconButton(tooltip: isArabic ? 'القائمة' : 'Menu', icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(scaffoldContext).openDrawer())),
          title: const Text('Zameel', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            PopupMenuButton<String>(
              tooltip: isArabic ? 'فلترة المنشورات' : 'Filter posts',
              icon: Badge(isLabelVisible: _feedScope != 'global', smallSize: 8, child: const Icon(Icons.filter_alt_outlined)),
              initialValue: _feedScope,
              onSelected: _setFeedScope,
              itemBuilder: (_) => [
                CheckedPopupMenuItem(value: 'global', checked: _feedScope == 'global', child: Text(isArabic ? 'العامة — جميع الطلبة' : 'Global — all students')),
                CheckedPopupMenuItem(value: 'college', checked: _feedScope == 'college', child: Text(isArabic ? 'الكلية' : 'College')),
                CheckedPopupMenuItem(value: 'department', checked: _feedScope == 'department', child: Text(isArabic ? 'التخصص' : 'Major')),
              ],
            ),
            IconButton(tooltip: isArabic ? 'البحث' : 'Search', icon: const Icon(Icons.search_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
            Stack(alignment: Alignment.center, children: [
              IconButton(tooltip: isArabic ? 'الإشعارات' : 'Notifications', icon: const Icon(Icons.notifications_none_rounded), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())); _loadUnreadNotifications(); }),
              if (_unreadNotifications > 0) Positioned(top: 7, right: 5, child: Container(constraints: const BoxConstraints(minWidth: 16, minHeight: 16), alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 3), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text(_unreadNotifications > 99 ? '99+' : '$_unreadNotifications', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
            ]),
            IconButton(tooltip: isArabic ? 'حسابي' : 'My profile', onPressed: () { final user = Supabase.instance.client.auth.currentUser; if (user != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.id))); }, icon: _ProfileAvatar(image: profileImage, imageBytes: profileImageBytes, imageUrl: profileImageUrl, radius: 16)),
            const SizedBox(width: 4),
          ],
        ),
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [gradientStart, gradientEnd],
                ),
              ),
              child: _buildCurrentPage(),
            ),
            Positioned(
              left: _arcMenuPosition?.dx ?? (isArabic ? 12 : MediaQuery.of(context).size.width - 262),
              top: _arcMenuPosition?.dy ?? (MediaQuery.of(context).padding.top + 10),
              child: _ZameelArcMenu(
                  isArabic: isArabic,
                  onChat: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
                  onCalendar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
                  onGroups: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsScreen())),
                  onBooks: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BooksScreen())),
                  onVideos: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ZameelSocialStudio(isArabic: isArabic))),
                  onDrag: _moveArcMenu,
                ),
            )
          ],
        ),
        floatingActionButton: currentIndex == 0
            ? FloatingActionButton(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                onPressed: createPost,
                child: const Icon(Icons.add_rounded),
              )
            : null,
        bottomNavigationBar: null,
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (currentIndex) {
      case 0:
        return _buildFeed();
      case 1:
        return const BooksScreen();
      case 2:
        return const ChatScreen();
      case 3:
        return const FriendsScreen();
      case 4:
        return const CampusScreen();
      case 5:
        return const MeetScreen();
      case 6:
        return const JobsScreen();
      case 7:
        return CalendarScreen();
      case 8:
        return const PollsScreen();
      case 9:
        return const PrivateGroupsScreen();
      case 10:
        return const AIScreen();
      case 11:
        return _buildProfilePage();
      default:
        return _buildFeed();
    }
  }

  Future<void> _sharePostToProfile(Map<String, dynamic> post) async {
    final user = Supabase.instance.client.auth.currentUser;
    final postId = post['id'];
    if (user == null || postId == null) return;
    if (post['is_demo'] == true) {
      final text = (post['text_ar'] ?? post['text_en'] ?? '').toString();
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ محتوى المنشور التجريبي ✓')));
      return;
    }
    try {
      await Supabase.instance.client.from('shared_posts').upsert({'post_id': postId, 'shared_by': user.id});
      await _loadPosts();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تمت مشاركة المنشور على ملفك الشخصي')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر مشاركة المنشور: $e')));
    }
  }

  Future<void> _showPostLikes(Map<String, dynamic> post) async {
    final postId = post['id'];
    if (postId == null) return;
    final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    try {
      final rows = await Supabase.instance.client.from('likes').select('user_id, created_at, users(name, profile_image)').eq('post_id', postId).order('created_at', ascending: false);
      if (!mounted) return;
      showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => Directionality(textDirection: ar ? TextDirection.rtl : TextDirection.ltr, child: SizedBox(height: 480, child: Column(children: [Padding(padding: const EdgeInsets.all(16), child: Text(ar ? 'الأشخاص الذين أعجبوا بالمنشور' : 'People who liked this post', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), Expanded(child: rows.isEmpty ? Center(child: Text(ar ? 'لا توجد إعجابات بعد' : 'No likes yet')) : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) { final u = rows[i]['users']; final name = u is Map ? (u['name']?.toString() ?? 'User') : 'User'; final image = u is Map ? u['profile_image']?.toString() : null; return ListTile(leading: CircleAvatar(backgroundImage: image != null && image.isNotEmpty ? NetworkImage(image) : null, child: image == null || image.isEmpty ? const Icon(Icons.person) : null), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))); }))]))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل الإعجابات: $e')));
    }
  }

  Widget _buildFeed() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;



    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    final visiblePosts = _visiblePosts;
    final scopeLabel = _feedScope == 'college'
        ? (isArabic ? 'منشورات الكلية' : 'College posts')
        : _feedScope == 'department'
            ? (isArabic ? 'منشورات التخصص' : 'Major posts')
            : (isArabic ? 'المنشورات العامة' : 'Global posts');
    final children = <Widget>[
      const StoriesWidget(),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
        child: Row(children: [
          const Icon(Icons.dynamic_feed_rounded, color: primaryColor),
          const SizedBox(width: 8),
          Text(scopeLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ]),
      ),
      _buildCreateBox(),

    ];

    if (visiblePosts.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 44),
          child: Column(
            children: [
              Icon(Icons.post_add_rounded,
                  size: 58, color: primaryColor.withOpacity(.35)),
              const SizedBox(height: 10),
              Text(
                isArabic ? '📭 لا توجد منشورات' : '📭 No posts',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isArabic
                    ? 'كن أول من ينشر شيئًا!'
                    : 'Be the first to post something!',
                style: const TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
        ),
      );
    } else {
      for (final post in visiblePosts) {
        final userData =
            post['users'] is Map ? Map<String, dynamic>.from(post['users']) : {};
        final isLiked = post['liked'] == true;
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: GlassContainer(
              child: _PostCard(
                post: {
                  ...post,
                  'name_ar': userData['name'] ?? 'مستخدم',
                  'name_en': userData['name'] ?? 'User',
                  'department_ar': userData['department'] ?? widget.department,
                  'department_en': userData['department'] ?? widget.department,
                  'time_ar': _formatTime(post['created_at']?.toString()),
                  'time_en': _formatTime(post['created_at']?.toString()),
                  'likes': post['likes_count'] ?? 0,
                  'comments': post['comments_count'] ?? 0,
                  'shares': post['shares_count'] ?? 0,
                  'profile_image': userData['profile_image'],
                  'liked': isLiked,
                },
                onLike: () => _toggleLike(posts.indexOf(post)),
                savedPosts: savedPosts,
                isAdmin: isAdmin,
                postOwnerId: post['user_id']?.toString(),
                onDelete: () => _showDeleteConfirmation(context, post),
                onShareToProfile: _sharePostToProfile,
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await _loadUnreadNotifications();
            await _loadPosts();
          },
          child: ListView(
            controller: _feedScrollController,
            padding: const EdgeInsets.only(bottom: 90),
            children: children,
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'feed_top',
            onPressed: () => _feedScrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
            child: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
        ),
      ],
    );
  }


  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'الآن';

    try {
      final time = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(time);

      if (diff.inSeconds < 60) return 'الآن';
      if (diff.inMinutes < 60) {
        return 'منذ ${diff.inMinutes} دقيقة';
      }
      if (diff.inHours < 24) {
        return 'منذ ${diff.inHours} ساعة';
      }
      if (diff.inDays < 7) {
        return 'منذ ${diff.inDays} يوم';
      }
      return 'منذ ${diff.inDays ~/ 7} أسبوع';
    } catch (e) {
      return 'الآن';
    }
  }


  Widget _buildCreateBox() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return GlassContainer(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ProfileAvatar(
                image: profileImage,
                imageBytes: profileImageBytes,
                imageUrl: profileImageUrl,
                radius: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: createPost,
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      Translations.translate(
                        'feed_share',
                        languageProvider.currentLanguage,
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(
            color: Colors.white24,
            height: 28,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _CreateAction(
                icon: Icons.videocam_outlined,
                text: Translations.translate(
                  'feed_video',
                  languageProvider.currentLanguage,
                ),
                onTap: _pickVideo,
              ),
              _CreateAction(
                icon: Icons.image_outlined,
                text: Translations.translate(
                  'feed_image',
                  languageProvider.currentLanguage,
                ),
                onTap: _pickImage,
              ),
              _CreateAction(
                icon: Icons.menu_book_outlined,
                text: Translations.translate(
                  'feed_book',
                  languageProvider.currentLanguage,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BooksScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return ListView(
      padding: const EdgeInsets.only(
        top: 80,
        bottom: 20,
      ),
      children: [
        GlassContainer(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              GestureDetector(
                onTap: pickProfileImage,
                child: Stack(
                  children: [
                    _ProfileAvatar(
                      image: profileImage,
                      imageBytes: profileImageBytes,
                      radius: 55,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                Translations.translate(
                  'profile_student',
                  languageProvider.currentLanguage,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                translateText(
                  widget.university.name,
                  languageProvider.currentLanguage,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${translateText(widget.college.name, languageProvider.currentLanguage)} • ${translateText(widget.department, languageProvider.currentLanguage)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ProfileOption(
          icon: Icons.bar_chart_rounded,
          title: isArabic ? '📊 الإحصاءات الشخصية' : '📊 Activity Stats',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StatsScreen(
                  postsCount: posts.length,
                  likesCount: posts.fold(
                    0,
                    (sum, post) => sum + ((post['likes_count'] ?? 0) as int),
                  ),
                  commentsCount: posts.fold(
                    0,
                    (sum, post) => sum + ((post['comments_count'] ?? 0) as int),
                  ),
                  friendsCount: 12,
                  savedBooksCount: 3,
                  activeDays: 45,
                ),
              ),
            );
          },
        ),
        _ProfileOption(
          icon: Icons.timeline_rounded,
          title: isArabic ? '⏰ النشاط' : '⏰ Activity',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⏰ عرض النشاط'),
                backgroundColor: primaryColor,
              ),
            );
          },
        ),
        _ProfileOption(
          icon: Icons.emoji_events_rounded,
          title: isArabic ? '🏆 الإنجازات' : '🏆 Achievements',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🏆 عرض الإنجازات'),
                backgroundColor: AppTheme.primary,
              ),
            );
          },
        ),
        _ProfileOption(
          icon: Icons.camera_alt_outlined,
          title: Translations.translate(
            'profile_change_image',
            languageProvider.currentLanguage,
          ),
          onTap: pickProfileImage,
        ),
        _ProfileOption(
          icon: Icons.edit_outlined,
          title: Translations.translate(
            'profile_edit_info',
            languageProvider.currentLanguage,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: null),
              ),
            );
          },
        ),
        _ProfileOption(
          icon: Icons.menu_book_outlined,
          title: Translations.translate(
            'profile_my_books',
            languageProvider.currentLanguage,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BooksScreen(),
              ),
            );
          },
        ),
        _ProfileOption(
          icon: Icons.school_rounded,
          title: Translations.translate(
            'graduation_book',
            languageProvider.currentLanguage,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GraduationBookScreen(
                  studentName: 'طالب Zameel',
                  university: widget.university.name,
                  major: widget.department,
                  graduationYear: '2024',
                ),
              ),
            );
          },
        ),

        _ProfileOption(
          icon: Icons.bookmark_border_rounded,
          title: Translations.translate(
            'profile_saved',
            languageProvider.currentLanguage,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SavedPostsScreen(
                  savedPosts: savedPosts,
                ),
              ),
            );
          },
        ),
        const Divider(
          color: Colors.white24,
          height: 30,
        ),
        _ProfileOption(
          icon: Icons.logout_rounded,
          title: isArabic ? '🚪 تسجيل الخروج' : '🚪 Logout',
          iconColor: Colors.red,
          onTap: () async {
            final confirm = await showDialog(
              context: context,
              builder: (dialogContext) {
                return Directionality(
                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                  child: AlertDialog(
                    backgroundColor: Colors.white.withAlpha(230),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Text(
                      isArabic ? 'تسجيل الخروج' : 'Logout',
                    ),
                    content: Text(
                      isArabic
                          ? 'هل أنت متأكد من رغبتك في تسجيل الخروج؟'
                          : 'Are you sure you want to logout?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(
                          isArabic ? 'إلغاء' : 'Cancel',
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          isArabic ? 'تسجيل الخروج' : 'Logout',
                        ),
                      ),
                    ],
                  ),
                );
              },
            );

            if (confirm == true) {
              await Supabase.instance.client.auth.signOut();

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const WelcomeScreen(),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

// ============================================================
// DRAWER ITEM
// ============================================================
