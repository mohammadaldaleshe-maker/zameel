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
  String? profileImage;
  Uint8List? profileImageBytes;
  String? profileImageUrl;
  String? profileName;
  final ImagePicker picker = ImagePicker();
  bool isAdmin = false;
  List<Map<String, dynamic>> savedPosts = [];
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> _advertisements = [];
  bool _isLoading = true;
  bool _mediaPublishing = false;
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
  List<String> _arcShortcutIds = <String>['chat', 'calendar', 'groups', 'books', 'clips'];

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _createUserIfNotExists();
  _loadCurrentProfileImage();
  _loadPosts();
  _loadAdvertisements();
  _loadUnreadNotifications();
  _subscribeToNotifications();
  _subscribeToFeedUpdates();
  _startFeedRefreshTimer();
  _loadArcMenuPosition();
  _loadArcShortcuts();
  _loadFeedScope();
  FeatureControl.instance.changes.addListener(_onFeatureChange);
  FeatureControl.instance.refresh(force: true);
}

void _onFeatureChange() {
  if (mounted) setState(() {});
  _loadAdvertisements();
}


void _startFeedRefreshTimer() {
  _feedRefreshTimer?.cancel();
  _feedRefreshTimer = Timer.periodic(
    // Realtime already refreshes the feed. This is only a recovery poll for a
    // dropped socket and intentionally stays infrequent to control API egress.
    const Duration(minutes: 10),
    (_) => _loadPosts(silent: true),
  );
}

Future<void> _loadFeedScope() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('zameel_feed_scope');
  if (mounted && <String>{'global', 'college', 'department'}.contains(saved)) {
    setState(() => _feedScope = saved!);
  }
}

Future<void> _loadAdvertisements() async {
  if (!FeatureControl.instance.enabled('partner_advertising')) {
    if (mounted && _advertisements.isNotEmpty) setState(() => _advertisements = []);
    return;
  }
  try {
    final loaded = await AdvertisingService.liveAds(limit: 12);
    if (mounted) setState(() => _advertisements = loaded);
  } catch (error) {
    debugPrint('Error loading advertisements: $error');
    if (mounted) setState(() => _advertisements = []);
  }
}

Future<void> _setFeedScope(String scope) async {
  if (!<String>{'global', 'college', 'department'}.contains(scope)) return;
  setState(() => _feedScope = scope);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('zameel_feed_scope', scope);
}

String get _arcShortcutPrefsKey {
  final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
  return 'zameel_arc_shortcuts_$userId';
}

Future<void> _loadArcShortcuts() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getStringList(_arcShortcutPrefsKey);
  if (!mounted || saved == null || saved.isEmpty) return;
  final allowed = _arcShortcutIdsAllowed.toSet();
  final clean = saved.where(allowed.contains).toSet().take(5).toList();
  if (clean.isNotEmpty) setState(() => _arcShortcutIds = clean);
}

List<String> get _arcShortcutIdsAllowed => const <String>[
  'home', 'books', 'chat', 'colleagues', 'campus', 'meet', 'jobs',
  'calendar', 'polls', 'groups', 'ai', 'partners', 'profile', 'clips', 'lamma',
  'radio', 'beautiful_college',
];

Future<void> _saveArcShortcuts(List<String> ids) async {
  final clean = ids.where(_arcShortcutIdsAllowed.contains).toSet().take(5).toList();
  if (clean.isEmpty) return;
  setState(() => _arcShortcutIds = clean);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_arcShortcutPrefsKey, clean);
}

List<_ArcItemData> _arcShortcutCatalog(bool ar) => <_ArcItemData>[
  _ArcItemData('home', Icons.home_rounded, ar ? 'الرئيسية' : 'Home', () => _openMenuDestination('home')),
  _ArcItemData('books', Icons.menu_book_rounded, ar ? 'الكتب' : 'Books', () => _openMenuDestination('books')),
  _ArcItemData('chat', Icons.chat_bubble_rounded, ar ? 'الدردشة' : 'Chat', () => _openMenuDestination('chat')),
  _ArcItemData('colleagues', Icons.people_rounded, ar ? 'زملاء' : 'Colleagues', () => _openMenuDestination('colleagues')),
  _ArcItemData('lamma', Icons.diversity_2_rounded, ar ? 'لَمّة' : 'Lamma', () => _openMenuDestination('lamma')),
  _ArcItemData('radio', Icons.podcasts_rounded, ar ? 'راديو Zameel' : 'Zameel Radio', () => _openMenuDestination('radio')),
  _ArcItemData('beautiful_college', Icons.photo_camera_back_rounded, ar ? 'أجمل كلية' : 'Beautiful College', () => _openMenuDestination('beautiful_college')),
  _ArcItemData('campus', Icons.map_rounded, ar ? 'الحرم الجامعي' : 'Campus', () => _openMenuDestination('campus')),
  _ArcItemData('meet', Icons.video_call_rounded, ar ? 'اجتمع بالزملاء' : 'Meet', () => _openMenuDestination('meet')),
  _ArcItemData('jobs', Icons.work_rounded, ar ? 'وظائف' : 'Jobs', () => _openMenuDestination('jobs')),
  _ArcItemData('calendar', Icons.calendar_month_rounded, ar ? 'تقويم' : 'Calendar', () => _openMenuDestination('calendar')),
  _ArcItemData('polls', Icons.poll_rounded, ar ? 'استطلاعات' : 'Polls', () => _openMenuDestination('polls')),
  _ArcItemData('groups', Icons.group_rounded, ar ? 'مجموعات' : 'Groups', () => _openMenuDestination('groups')),
  _ArcItemData('ai', Icons.auto_awesome_rounded, 'Zameel AI', () => _openMenuDestination('ai')),
  _ArcItemData('partners', Icons.business_center_rounded, ar ? 'شركاء Zameel' : 'Partners', () => _openMenuDestination('partners')),
  _ArcItemData('profile', Icons.person_rounded, ar ? 'حسابي' : 'Profile', () => _openMenuDestination('profile')),
  _ArcItemData('clips', Icons.movie_creation_rounded, ar ? 'كليبسات' : 'Clips', () => _openMenuDestination('clips')),
];

String _featureForShortcut(String id) => const <String, String>{
  'books':'books_market', 'chat':'direct_chat', 'colleagues':'suggested_colleagues',
  'lamma':'lamma', 'radio':'zameel_radio', 'beautiful_college':'beautiful_college',
  'campus':'campus_world', 'meet':'zameel_meet', 'jobs':'jobs_training',
  'calendar':'university_calendar', 'polls':'polls', 'groups':'groups',
  'ai':'zameel_ai', 'partners':'business_partners', 'clips':'clips',
}[id] ?? id;

void _openMenuDestination(String id) {
  final feature = _featureForShortcut(id);
  if (!FeatureControl.instance.enabled(feature)) {
    FeatureControl.instance.open(context, feature, () => const SizedBox.shrink());
    return;
  }
  switch (id) {
    case 'home':
      setState(() => currentIndex = 0);
      break;
    case 'books':
      FeatureControl.instance.open(context, 'books_market', () => const BooksScreen());
      break;
    case 'chat':
      FeatureControl.instance.open(context, 'direct_chat', () => const ChatScreen());
      break;
    case 'colleagues':
      FeatureControl.instance.open(context, 'suggested_colleagues', () => const FriendsScreen());
      break;
    case 'lamma':
      FeatureControl.instance.open(context, 'lamma', () => const LammaScreen());
      break;
    case 'radio':
      FeatureControl.instance.open(context, 'zameel_radio', () => const ZameelRadioScreen());
      break;
    case 'beautiful_college':
      FeatureControl.instance.open(context, 'beautiful_college', () => const BeautifulCollegeScreen());
      break;
    case 'campus':
      FeatureControl.instance.open(context, 'campus_world', () => const CampusScreen());
      break;
    case 'meet':
      FeatureControl.instance.open(context, 'zameel_meet', () => const MeetScreen());
      break;
    case 'jobs':
      FeatureControl.instance.open(context, 'jobs_training', () => const JobsScreen());
      break;
    case 'calendar':
      FeatureControl.instance.open(context, 'university_calendar', () => const CalendarScreen());
      break;
    case 'polls':
      FeatureControl.instance.open(context, 'polls', () => const PollsScreen());
      break;
    case 'groups':
      FeatureControl.instance.open(context, 'groups', () => const GroupsScreen());
      break;
    case 'ai':
      FeatureControl.instance.open(context, 'zameel_ai', () => const AIScreen());
      break;
    case 'partners':
      FeatureControl.instance.open(context, 'business_partners', () => const BusinessScreen());
      break;
    case 'profile':
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.id)));
      }
      break;
    case 'clips':
      final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
      FeatureControl.instance.open(context, 'clips', () => ZameelSocialStudio(isArabic: ar));
      break;
  }
}

Future<void> _showArcShortcutCustomizer() async {
  final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
  var selected = List<String>.from(_arcShortcutIds);
  final catalog = _arcShortcutCatalog(ar).where((e) => FeatureControl.instance.visible(_featureForShortcut(e.id))).toList();
  final result = await showDialog<List<String>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(ar ? 'تخصيص الزر العائم' : 'Customize floating menu'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ar ? 'اختر من 1 إلى 5 اختصارات من القائمة.' : 'Choose 1 to 5 shortcuts from the menu.',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 8),
                ...catalog.map((item) {
                  final checked = selected.contains(item.id);
                  return CheckboxListTile(
                    value: checked,
                    secondary: Icon(item.icon, color: AppTheme.primary),
                    title: Text(item.label),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          if (selected.length < 5 && !selected.contains(item.id)) selected.add(item.id);
                        } else {
                          selected.remove(item.id);
                        }
                      });
                    },
                  );
                }),
                Text(
                  ar ? 'المحدد: ${selected.length}/5' : 'Selected: ${selected.length}/5',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: selected.isEmpty ? null : () => Navigator.pop(dialogContext, selected),
            child: Text(ar ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    ),
  );
  if (result != null && result.isNotEmpty) await _saveArcShortcuts(result);
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
    FeatureControl.instance.changes.removeListener(_onFeatureChange);
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
    _startFeedRefreshTimer();
    FeatureControl.instance.refresh(force: true);
    _loadPosts(silent: true);
    _loadUnreadNotifications();
  } else if (state == AppLifecycleState.inactive ||
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached) {
    _feedRefreshTimer?.cancel();
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
    final rows = await Supabase.instance.client.from('notifications')
        .select('id,type,data,actor_id').eq('user_id', user.id).eq('is_read', false);
    final count = MessageNotificationGrouping.collapse(
        List<Map<String, dynamic>>.from(rows)).length;
    if (mounted) setState(() => _unreadNotifications = count);
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
  if (!await FeatureControl.instance.check(context, 'direct_calls')) return;
  final notificationId = n['id']?.toString() ?? '';
  if (notificationId.isEmpty || _handledIncomingCalls.contains(notificationId)) {
    return;
  }

  final data = _notificationData(n);
  final roomId = data['room_id']?.toString() ?? '';
  if (!await CallInvitationGuard.isRinging(roomId)) return;

  _handledIncomingCalls.add(notificationId);
  _incomingCallDialogOpen = true;

  final type = n['type']?.toString() ?? '';
  final video = data['video'] == true ||
      data['video']?.toString().toLowerCase() == 'true' ||
      type == 'incoming_video_call';
  final actorId = n['actor_id']?.toString();
  String callerName = 'Colleague';
  String? callerImage;
  if (actorId != null && actorId.isNotEmpty) {
    try {
      final actor = await Supabase.instance.client
          .from('users')
          .select('name,profile_image')
          .eq('id', actorId)
          .maybeSingle();
      final name = actor?['name']?.toString().trim();
      if (name != null && name.isNotEmpty) callerName = name;
      callerImage = actor?['profile_image']?.toString();
    } catch (_) {}
  }

  if (!mounted) {
    _incomingCallDialogOpen = false;
    return;
  }

  final accepted = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => IncomingCallScreen(roomId: roomId, callerName: callerName, callerImage: callerImage, video: video),
    ),
  );
  _incomingCallDialogOpen = false;

  try {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  } catch (_) {}

  if (accepted != true) {
    try { await Supabase.instance.client.from('direct_call_sessions').update({'status':'declined','ended_at':DateTime.now().toUtc().toIso8601String()}).eq('room_id',roomId).eq('status','ringing'); } catch (_) {}
    return;
  }
  if (!await CallInvitationGuard.isRinging(roomId)) return;
  if (!mounted) return;
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
  final oldOffset = _feedScrollController.hasClients ? _feedScrollController.offset : 0.0;
  final oldMaxExtent = _feedScrollController.hasClients ? _feedScrollController.position.maxScrollExtent : 0.0;
  final oldFirstId = posts.isEmpty ? null : posts.first['id']?.toString();
  if (!silent && mounted) setState(() => _isLoading = true);
  try {
    final db = Supabase.instance.client;
    final response = await db
        .from('posts')
        .select('*, users(name, profile_image, gender, role, university, college, department)')
        .order('created_at', ascending: false)
        .limit(30);

    // Production feed: use only posts that actually exist in Supabase.
    // Demo posts use synthetic IDs and cannot participate in DB-backed
    // features such as comments, likes, saves, or sharing.
    final loaded = List<Map<String, dynamic>>.from(response);
    await SecureMediaService.resolvePosts(loaded);
    final user = db.auth.currentUser;

    if (user != null && loaded.isNotEmpty) {
      try {
        final loadedIds = loaded
            .map((post) => post['id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
        final personalState = await Future.wait([
          db
              .from('likes')
              .select('post_id')
              .eq('user_id', user.id)
              .inFilter('post_id', loadedIds),
          db
              .from('saved_posts')
              .select('post_id')
              .eq('user_id', user.id)
              .inFilter('post_id', loadedIds),
        ]);
        final likes = personalState[0];
        final saved = personalState[1];
        final likedIds = likes.map((r) => r['post_id'].toString()).toSet();
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
    final newFirstId = loaded.isEmpty ? null : loaded.first['id']?.toString();
    if (silent && oldOffset > 20 && oldFirstId != null && newFirstId != oldFirstId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_feedScrollController.hasClients) return;
        final newMax = _feedScrollController.position.maxScrollExtent;
        final addedExtent = newMax > oldMaxExtent ? newMax - oldMaxExtent : 0.0;
        final target = oldOffset + addedExtent;
        _feedScrollController.jumpTo(target > newMax ? newMax : target);
      });
    }
  } catch (e) {
    debugPrint('Error loading posts: $e');
    if (mounted && !silent) setState(() => _isLoading = false);
  }
}

List<Map<String, dynamic>> _diversifyFeed(
    List<Map<String, dynamic>> source) {
  // Preserve the relevance/recency order returned by the backend. Gender is
  // deliberately not used as a ranking signal anywhere in the home feed.
  return List<Map<String, dynamic>>.from(source);
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

  Future<void> _createPost(
    String text, {
    String? audience,
    List<PickedPostMedia> media = const <PickedPostMedia>[],
  }) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ الرجاء تسجيل الدخول')),
        );
      }
      return;
    }

    // Keep the already-tested text-only publishing path unchanged.
    if (media.isEmpty) {
      try {
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

        if (!mounted) return;
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
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FeatureControl.errorMessage(e, '❌ فشل النشر')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_mediaPublishing) return;
    if (mounted) setState(() => _mediaPublishing = true);

    try {
      if (mounted) {
        final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ar
                  ? 'جاري رفع ${media.length} ملف وسائط ونشر المنشور...'
                  : 'Uploading ${media.length} media item(s) and publishing...',
            ),
          ),
        );
      }

      final response = await PostPublishService.publishPost(
        text: text,
        audience: audience ?? _postAudience,
        media: media,
      );

      if (!mounted) return;
      setState(() {
        posts.insert(0, {
          ...response,
          'users': {
            'name': profileName ?? user.userMetadata?['name'] ?? 'مستخدم',
            'profile_image': profileImageUrl,
            'department': widget.department,
          },
          'liked': false,
          'isSaved': false,
          'shares': response['shares_count'] ?? 0,
        });
      });

      final ar = Provider.of<LanguageProvider>(context, listen: false).isArabic;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ar
                ? '✅ تم نشر المنشور مع ${media.length} ملف وسائط!'
                : '✅ Post published with ${media.length} media item(s)!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FeatureControl.errorMessage(e, '❌ فشل النشر')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _mediaPublishing = false);
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
      await PostPublishService.deletePost(post['id'].toString());

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
          content: Text(FeatureControl.errorMessage(e, '❌ فشل الحذف')),
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
        SnackBar(content: Text(FeatureControl.errorMessage(e, 'تعذر تحديث الإعجاب'))),
      );
    }
  }

  // ============================================================
  // حفظ منشور
  // ============================================================

  Future<void> _toggleSavePost(int index) async {
    if (!await FeatureControl.instance.check(context, 'saved_posts')) return;
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
        // Keep the local path for native platforms; Web uses profileImageBytes.
        profileImage = kIsWeb ? null : image.path;
      });
    }
  }

  void toggleLike(int index) {
    _toggleLike(index);
  }

  Future<void> _pickImage() async {
    if (_mediaPublishing) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final source = await _chooseMediaSource();
      if (source == null) return;

      final media = <PickedPostMedia>[];
      if (source == ImageSource.camera) {
        final image = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
        );
        if (image == null) return;
        media.add(PickedPostMedia(source: image, byteSize: await image.length()));
      } else {
        media.addAll(await PostPublishService.pickMultipleImages(limit: PostPublishService.maxSelectableMedia));
      }
      if (media.isEmpty) return;

      final audience = await _choosePostAudience();
      if (audience == null) return;
      await _createPost('', audience: audience, media: media);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FeatureControl.errorMessage(e, 'فشل اختيار/نشر الصور')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
    if (_mediaPublishing) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final source = await _chooseMediaSource();
      if (source == null) return;

      final media = <PickedPostMedia>[];
      if (source == ImageSource.camera) {
        final video = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 45),
        );
        if (video == null) return;
        media.add(PickedPostMedia(source: video, byteSize: await video.length()));
      } else {
        media.addAll(await PostPublishService.pickMultipleVideos(limit: PostPublishService.maxSelectableMedia));
      }
      if (media.isEmpty) return;

      final audience = await _choosePostAudience();
      if (audience == null) return;
      await _createPost('', audience: audience, media: media);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FeatureControl.errorMessage(e, 'فشل اختيار/نشر الفيديوهات')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<ImageSource?> _chooseMediaSource() => showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('التصوير الآن'),
              subtitle: const Text('الفيديو بحد أقصى 45 ثانية'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('اختيار من الهاتف'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ]),
        ),
      );

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
    final selectedMedia = <PickedPostMedia>[];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => Directionality(
            textDirection: languageProvider.isArabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: AlertDialog(
              backgroundColor: Colors.white.withAlpha(242),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                Translations.translate(
                  'create_post_title',
                  languageProvider.currentLanguage,
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _postAudience,
                        decoration: InputDecoration(
                          labelText: languageProvider.isArabic
                              ? 'من يمكنه رؤية المنشور؟'
                              : 'Who can see this post?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'public',
                            child: Text(languageProvider.isArabic ? '🌍 عامة' : '🌍 Public'),
                          ),
                          DropdownMenuItem(
                            value: 'friends',
                            child: Text(languageProvider.isArabic ? '👥 الزملاء' : '👥 Colleagues'),
                          ),
                          DropdownMenuItem(
                            value: 'private',
                            child: Text(languageProvider.isArabic ? '🔒 لي فقط' : '🔒 Only me'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _postAudience = value;
                            setDialogState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: controller,
                        maxLines: 5,
                        autofocus: true,
                        style: const TextStyle(color: Colors.black),
                        cursorColor: Colors.black,
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
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: selectedMedia.length >= PostPublishService.maxSelectableMedia
                              ? null
                              : () async {
                                  final result = await PostPublishService.pickMultipleMedia(
                                    limit: PostPublishService.maxSelectableMedia - selectedMedia.length,
                                  );
                                  if (result.isEmpty) return;

                                  final existing = selectedMedia
                                      .map((file) => '${file.name}:${file.path}')
                                      .toSet();
                                  for (final file in result) {
                                    if (!PostPublishService.isSupportedFile(file)) continue;
                                    final key = '${file.name}:${file.path}';
                                    if (!existing.add(key)) continue;
                                    if (selectedMedia.length >= PostPublishService.maxSelectableMedia) break;
                                    selectedMedia.add(file);
                                  }
                                  setDialogState(() {});
                                },
                          icon: const Icon(Icons.collections_rounded),
                          label: Text(
                            languageProvider.isArabic
                                ? 'إضافة صور وفيديوهات (${selectedMedia.length}/${PostPublishService.maxSelectableMedia})'
                                : 'Add photos & videos (${selectedMedia.length}/${PostPublishService.maxSelectableMedia})',
                          ),
                        ),
                      ),
                      if (selectedMedia.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...List.generate(selectedMedia.length, (index) {
                          final file = selectedMedia[index];
                          final video = PostPublishService.isVideoFile(file);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                video ? Icons.videocam_rounded : Icons.image_rounded,
                                color: video ? AppTheme.primaryDark : AppTheme.primary,
                              ),
                              title: Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black87),
                              ),
                              subtitle: Builder(
                                builder: (_) {
                                  final size = file.lengthSync;
                                  return Text(
                                    '${(size / (1024 * 1024)).toStringAsFixed(1)} MB',
                                    style: const TextStyle(color: Colors.black54),
                                  );
                                },
                              ),
                              trailing: IconButton(
                                tooltip: languageProvider.isArabic ? 'إزالة' : 'Remove',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  selectedMedia.removeAt(index);
                                  setDialogState(() {});
                                },
                              ),
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    Translations.translate(
                      'create_post_cancel',
                      languageProvider.currentLanguage,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty && selectedMedia.isEmpty) return;

                    final media = List<PickedPostMedia>.from(selectedMedia);
                    Navigator.pop(dialogContext);
                    await _createPost(
                      text,
                      audience: _postAudience,
                      media: media,
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
            if (FeatureControl.instance.visible('books_market')) _DrawerItem(
              icon: Icons.menu_book_rounded,
              title: isArabic ? 'الكتب' : 'Books',
              onTap: () {
                FeatureControl.instance.open(context, 'books_market', () => const BooksScreen());
              },
            ),
            if (FeatureControl.instance.visible('direct_chat')) _DrawerItem(
              icon: Icons.chat_bubble_rounded,
              title: isArabic ? 'الدردشة' : 'Chat',
              onTap: () {
                FeatureControl.instance.open(context, 'direct_chat', () => const ChatScreen());
              },
            ),
            if (FeatureControl.instance.visible('suggested_colleagues')) _DrawerItem(
              icon: Icons.people_rounded,
              title: isArabic ? 'زملاء' : 'Colleagues',
              onTap: () {
                FeatureControl.instance.open(context, 'suggested_colleagues', () => const FriendsScreen());
              },
            ),
            if (FeatureControl.instance.visible('lamma')) _DrawerItem(
              icon: Icons.diversity_2_rounded,
              title: isArabic ? 'لَمّة' : 'Lamma',
              onTap: () {
                FeatureControl.instance.open(context, 'lamma', () => const LammaScreen());
              },
            ),
            if (FeatureControl.instance.visible('zameel_radio')) _DrawerItem(
              icon: Icons.podcasts_rounded,
              title: isArabic ? 'راديو Zameel' : 'Zameel Radio',
              onTap: () {
                FeatureControl.instance.open(context, 'zameel_radio', () => const ZameelRadioScreen());
              },
            ),
            if (FeatureControl.instance.visible('beautiful_college')) _DrawerItem(
              icon: Icons.photo_camera_back_rounded,
              title: isArabic ? 'تحدي أجمل كلية' : 'Beautiful College Challenge',
              onTap: () {
                FeatureControl.instance.open(context, 'beautiful_college', () => const BeautifulCollegeScreen());
              },
            ),
            if (FeatureControl.instance.visible('campus_world')) _DrawerItem(
              icon: Icons.map_rounded,
              title: isArabic ? 'الحرم الجامعي' : 'Campus',
              onTap: () {
                FeatureControl.instance.open(context, 'campus_world', () => const CampusScreen());
              },
            ),
            if (FeatureControl.instance.visible('zameel_meet')) _DrawerItem(
              icon: Icons.video_call_rounded,
              title: isArabic ? 'اجتمع بالزملاء' : 'Meet',
              onTap: () {
                FeatureControl.instance.open(context, 'zameel_meet', () => const MeetScreen());
              },
            ),
            if (FeatureControl.instance.visible('jobs_training')) _DrawerItem(
              icon: Icons.work_rounded,
              title: isArabic ? 'وظائف' : 'Jobs',
              onTap: () {
                FeatureControl.instance.open(context, 'jobs_training', () => const JobsScreen());
              },
            ),
            if (FeatureControl.instance.visible('university_calendar')) _DrawerItem(
              icon: Icons.calendar_month_rounded,
              title: isArabic ? 'تقويم' : 'Calendar',
              onTap: () {
                FeatureControl.instance.open(context, 'university_calendar', () => CalendarScreen());
              },
            ),
            if (FeatureControl.instance.visible('polls')) _DrawerItem(
              icon: Icons.poll_rounded,
              title: isArabic ? 'استطلاعات' : 'Polls',
              onTap: () {
                FeatureControl.instance.open(context, 'polls', () => const PollsScreen());
              },
            ),
            if (FeatureControl.instance.visible('groups')) _DrawerItem(
              icon: Icons.group_rounded,
              title: isArabic ? 'مجموعات' : 'Groups',
              onTap: () {
                FeatureControl.instance.open(context, 'groups', () => const GroupsScreen());
              },
            ),
            if (FeatureControl.instance.visible('clips')) _DrawerItem(
              icon: Icons.movie_creation_rounded,
              title: isArabic ? 'كليبسات' : 'Clips',
              onTap: () {
                FeatureControl.instance.open(context, 'clips', () => ZameelSocialStudio(isArabic: isArabic));
              },
            ),
            if (FeatureControl.instance.visible('zameel_ai')) _DrawerItem(
              icon: Icons.auto_awesome_rounded,
              title: isArabic ? 'Zameel AI' : 'Zameel AI',
              onTap: () {
                FeatureControl.instance.open(context, 'zameel_ai', () => const AIScreen());
              },
            ),
            if (FeatureControl.instance.visible('business_partners')) _DrawerItem(
              icon: Icons.business_center_rounded,
              title: isArabic ? 'شركاء Zameel' : 'Zameel Partners',
              onTap: () {
                FeatureControl.instance.open(context, 'business_partners', () => const BusinessScreen());
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
            _DrawerItem(
              icon: Icons.tune_rounded,
              title: isArabic ? 'تخصيص الزر العائم' : 'Customize floating menu',
              onTap: () {
                Navigator.pop(context);
                Future<void>.delayed(const Duration(milliseconds: 180), _showArcShortcutCustomizer);
              },
            ),
            const Divider(
              color: Colors.white24,
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
                  await AuthSessionService.signOut();

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
        drawerEdgeDragWidth: 28,
        drawerEnableOpenDragGesture: true,
        appBar: AppBar(
          backgroundColor: Colors.white, foregroundColor: primaryColor, elevation: 1,
          leading: Builder(builder: (scaffoldContext) => IconButton(tooltip: isArabic ? 'القائمة' : 'Menu', icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(scaffoldContext).openDrawer())),
          title: const Text(
            'Zameel',
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            if (FeatureControl.instance.visible('direct_calls')) IconButton(
              tooltip: isArabic ? 'اتصال' : 'Call',
              icon: const Icon(Icons.add_call),
              onPressed: () => FeatureControl.instance.open(context, 'direct_calls', () => const ContactCallsScreen()),
            ),
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
            if (FeatureControl.instance.visible('global_search')) IconButton(tooltip: isArabic ? 'البحث' : 'Search', icon: const Icon(Icons.search_rounded), onPressed: () => FeatureControl.instance.open(context, 'global_search', () => const SearchScreen())),
            if (FeatureControl.instance.visible('notifications_center')) Stack(alignment: Alignment.center, children: [
              IconButton(tooltip: isArabic ? 'الإشعارات' : 'Notifications', icon: const Icon(Icons.notifications_none_rounded), onPressed: () async { await FeatureControl.instance.open(context, 'notifications_center', () => const NotificationsScreen()); _loadUnreadNotifications(); }),
              if (_unreadNotifications > 0) Positioned(top: 7, right: 5, child: Container(constraints: const BoxConstraints(minWidth: 16, minHeight: 16), alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 3), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text(_unreadNotifications > 99 ? '99+' : '$_unreadNotifications', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
            ]),
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
                  items: _arcShortcutCatalog(isArabic)
                      .where((item) => _arcShortcutIds.contains(item.id) && FeatureControl.instance.visible(_featureForShortcut(item.id)))
                      .toList()
                    ..sort((a, b) => _arcShortcutIds.indexOf(a.id).compareTo(_arcShortcutIds.indexOf(b.id))),
                  onDrag: _moveArcMenu,
                  onCustomize: _showArcShortcutCustomizer,
                ),
            )
          ],
        ),
        floatingActionButton: currentIndex == 0 && FeatureControl.instance.visible('feed_posts')
            ? FloatingActionButton(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                onPressed: () async { if (await FeatureControl.instance.check(context, 'feed_posts') && mounted) createPost(); },
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
        return FeatureControl.instance.enabled('feed_posts') ? _buildFeed() : const Center(child: Text(FeatureControl.suspendedMessage));
      case 1:
        return FeatureControl.instance.page('books_market', const BooksScreen());
      case 2:
        return FeatureControl.instance.page('direct_chat', const ChatScreen());
      case 3:
        return FeatureControl.instance.page('suggested_colleagues', const FriendsScreen());
      case 4:
        return FeatureControl.instance.page('campus_world', const CampusScreen());
      case 5:
        return FeatureControl.instance.page('zameel_meet', const MeetScreen());
      case 6:
        return FeatureControl.instance.page('jobs_training', const JobsScreen());
      case 7:
        return FeatureControl.instance.page('university_calendar', CalendarScreen());
      case 8:
        return FeatureControl.instance.page('polls', const PollsScreen());
      case 9:
        return FeatureControl.instance.page('groups', const PrivateGroupsScreen());
      case 10:
        return FeatureControl.instance.page('zameel_ai', const AIScreen());
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(FeatureControl.errorMessage(e, 'تعذر مشاركة المنشور'))));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(FeatureControl.errorMessage(e, 'تعذر تحميل الإعجابات'))));
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
      if (FeatureControl.instance.visible('stories'))
        FeatureControl.instance.page('stories', const StoriesWidget(), embedded: true),
      _buildCreateBox(),
      if (FeatureControl.instance.visible('clips'))
        FeatureControl.instance.page('clips', const PublicClipsStrip(), embedded: true),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
        child: Row(children: [
          const Icon(Icons.dynamic_feed_rounded, color: primaryColor),
          const SizedBox(width: 8),
          Text(scopeLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ]),
      ),
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
      for (var postIndex = 0; postIndex < visiblePosts.length; postIndex++) {
        final post = visiblePosts[postIndex];
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
        if ((postIndex + 1) % 5 == 0 &&
            FeatureControl.instance.enabled('partner_advertising')) {
          final adIndex = (postIndex + 1) ~/ 5 - 1;
          if (adIndex < _advertisements.length) {
            final ad = _advertisements[adIndex];
            children.add(AdvertisementCard(
              ad: ad, isArabic: isArabic,
              onHide: () async {
                await AdvertisingService.hide(ad['id'].toString());
                if (mounted) setState(() => _advertisements.removeWhere(
                  (item) => item['id'] == ad['id'],
                ));
              },
            ));
          }
        }
        if (postIndex == 4 && visiblePosts.length >= 5) {
          if (FeatureControl.instance.visible('suggested_colleagues')) {
            children.add(FeatureControl.instance.page('suggested_colleagues', const SuggestedColleaguesSection(), embedded: true));
          }
        }
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


  Future<void> _openCreateMenu() async {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final isArabic = languageProvider.isArabic;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Align(
                  alignment: isArabic
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    isArabic
                        ? 'ماذا تريد أن تشارك؟'
                        : 'What would you like to share?',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ComposerMenuAction(
                        icon: Icons.edit_note_rounded,
                        label: isArabic ? 'منشور' : 'Post',
                        onTap: () => Navigator.pop(sheetContext, 'post'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ComposerMenuAction(
                        icon: Icons.image_rounded,
                        label: isArabic ? 'صورة' : 'Photo',
                        onTap: () => Navigator.pop(sheetContext, 'image'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ComposerMenuAction(
                        icon: Icons.videocam_rounded,
                        label: isArabic ? 'فيديو' : 'Video',
                        onTap: () => Navigator.pop(sheetContext, 'video'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ComposerMenuAction(
                        icon: Icons.smart_display_rounded,
                        label: isArabic ? 'كليبس' : 'Clip',
                        onTap: () => Navigator.pop(sheetContext, 'clip'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'post':
        createPost();
        break;
      case 'image':
        await _pickImage();
        break;
      case 'video':
        await _pickVideo();
        break;
      case 'clip':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ZameelSocialStudio(isArabic: isArabic),
          ),
        );
        break;
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
                  onTap: _openCreateMenu,
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (FeatureControl.instance.visible('books_market')) _CreateAction(
                  icon: Icons.menu_book_outlined,
                  text: Translations.translate('feed_book', languageProvider.currentLanguage),
                  onTap: () => FeatureControl.instance.open(context, 'books_market', () => const BooksScreen()),
                ),
                const SizedBox(width: 14),
                if (FeatureControl.instance.visible('lamma')) _CreateAction(
                  icon: Icons.groups_rounded,
                  text: languageProvider.isArabic ? 'لَمّة' : 'Lamma',
                  onTap: () => FeatureControl.instance.open(context, 'lamma', () => const LammaScreen()),
                ),
                const SizedBox(width: 14),
                if (FeatureControl.instance.visible('zameel_radio')) _CreateAction(
                  icon: Icons.podcasts_rounded,
                  text: languageProvider.isArabic ? 'راديو زميل' : 'Zameel Radio',
                  onTap: () => FeatureControl.instance.open(context, 'zameel_radio', () => const ZameelRadioScreen()),
                ),
                const SizedBox(width: 14),
                if (FeatureControl.instance.visible('beautiful_college')) _CreateAction(
                  icon: Icons.photo_camera_back_rounded,
                  text: languageProvider.isArabic ? 'أجمل كلية' : 'Beautiful College',
                  onTap: () => FeatureControl.instance.open(context, 'beautiful_college', () => const BeautifulCollegeScreen()),
                ),
              ],
            ),
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
              await AuthSessionService.signOut();

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

class _ComposerMenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ComposerMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F1FF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFF245BDB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 25),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DRAWER ITEM
// ============================================================
