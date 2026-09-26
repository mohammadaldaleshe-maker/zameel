import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../profile/profile_screen.dart';
import '../comments/comments_screen.dart';
import '../books/books_screen.dart';
import '../../services_book_exchange.dart';
import 'package:zameel/theme/app_theme.dart';
import '../../services/secure_media_service.dart';
import '../../services/advertising_service.dart';
import '../../services/feature_control.dart';
import '../business/advertisement_card.dart';

// ============================================================
// ADVANCED SEARCH SCREEN
// ============================================================

// مستخدمو زميل التجريبيون
// ignore: unused_element
const _demoSearchUsers = [
  {'name':'ليان الخطيب','department':'علوم الحاسوب','university':'الجامعة الأردنية'},
  {'name':'آدم الحوراني','department':'هندسة البرمجيات','university':'جامعة العلوم والتكنولوجيا الأردنية'},
  {'name':'نور العزام','department':'إدارة الأعمال','university':'الجامعة الهاشمية'},
  {'name':'يوسف الشديفات','department':'الهندسة المدنية','university':'جامعة اليرموك'},
  {'name':'رؤى المومني','department':'الصيدلة','university':'جامعة العلوم التطبيقية الخاصة'},
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0 = الكل, 1 = مستخدمين, 2 = منشورات, 3 = كتب

  // المستخدمون التجريبيون: محفوظون في المصدر لمرجع التطوير ولا يُعرضون في البحث الحي.
  // ignore: unused_field
  final List<Map<String, dynamic>> _users = [
    {'name': 'ليان الخطيب','department':'علوم الحاسوب','university':'الجامعة الأردنية','isDemo': true},
    {'name':'آدم الحوراني','department':'هندسة البرمجيات','university':'جامعة العلوم والتكنولوجيا الأردنية','isDemo': true},
    {'name':'نور العزام','department':'إدارة الأعمال','university':'الجامعة الهاشمية','isDemo': true},
    {'name':'يوسف الشديفات','department':'الهندسة المدنية','university':'جامعة اليرموك','isDemo': true},
    {'name':'رؤى المومني','department':'الصيدلة','university':'جامعة العلوم التطبيقية الخاصة','isDemo': true},
  ];

  // ignore: unused_field
  final List<Map<String, dynamic>> _posts = [
    {'text': 'شرح سريع لفكرة مهمة في قواعد البيانات 📚', 'author': 'محمد أحمد', 'likes': 128},
    {'text': 'يا جماعة، هل يوجد أحد لديه ملخص مرتب للفصل الرابع؟', 'author': 'سارة علي', 'likes': 44},
    {'text': 'تم رفع ملخص مادة البرمجة على المجموعة', 'author': 'أحمد خالد', 'likes': 67},
  ];

  // ignore: unused_field
  final List<Map<String, dynamic>> _books = [
    {'title': 'مقدمة في قواعد البيانات', 'author': 'د. أحمد العلي', 'subject': 'قواعد البيانات'},
    {'title': 'هندسة البرمجيات', 'author': 'د. محمد سعيد', 'subject': 'هندسة البرمجيات'},
    {'title': 'الرياضيات المتقدمة', 'author': 'د. خالد الحسين', 'subject': 'الرياضيات'},
  ];

  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _filteredPosts = [];
  List<Map<String, dynamic>> _filteredBooks = [];
  List<Map<String, dynamic>> _filteredAdvertisements = [];
  bool _isSearching = false;
  String? _searchError;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _filteredUsers = [];
        _filteredPosts = [];
        _filteredBooks = [];
        _filteredAdvertisements = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    final rawQuery = query.trim();
    final safeQuery = rawQuery.replaceAll(RegExp(r'[,()]'), ' ').trim();
    if (safeQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final db = Supabase.instance.client;
        final currentId = db.auth.currentUser?.id;
        final pattern = '%$safeQuery%';

        final results = await Future.wait<dynamic>([
          db
              .from('users')
              .select('id,name,university,college,department,profile_image')
              .or('name.ilike.$pattern,university.ilike.$pattern,college.ilike.$pattern,department.ilike.$pattern')
              .limit(30),
          db
              .from('posts')
              .select('*, users(name,profile_image,gender,role,university,college,department)')
              .or('text_ar.ilike.$pattern,text_en.ilike.$pattern')
              .order('created_at', ascending: false)
              .limit(30),
          ZameelBookExchangeService.searchBooks(safeQuery, limit: 30),
          FeatureControl.instance.enabled('partner_advertising')
              ? AdvertisingService.liveAds(query: safeQuery, limit: 10).catchError((_) => <Map<String, dynamic>>[])
              : Future.value(<Map<String, dynamic>>[]),
        ]);

        final users = List<Map<String, dynamic>>.from(results[0] as List)
            .where((u) => currentId == null || u['id']?.toString() != currentId)
            .toList();
        final posts = List<Map<String, dynamic>>.from(results[1] as List);
        await SecureMediaService.resolvePosts(posts);
        final books = List<Map<String, dynamic>>.from(results[2] as List);
        final advertisements = List<Map<String, dynamic>>.from(results[3] as List);

        if (!mounted || _searchController.text.trim() != rawQuery) return;
        setState(() {
          _filteredUsers = users;
          _filteredPosts = posts;
          _filteredBooks = books;
          _filteredAdvertisements = advertisements;
          _isSearching = true;
          _searchError = null;
        });
      } catch (e) {
        if (!mounted || _searchController.text.trim() != rawQuery) return;
        setState(() {
          _filteredUsers = [];
          _filteredPosts = [];
          _filteredBooks = [];
          _filteredAdvertisements = [];
          _isSearching = true;
          _searchError = e.toString();
        });
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchController.clear();
      _filteredUsers = [];
      _filteredPosts = [];
      _filteredBooks = [];
      _filteredAdvertisements = [];
      _isSearching = false;
      _searchError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? '🔍 بحث متقدم' : '🔍 Advanced Search',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _performSearch,
                style: const TextStyle(color: Colors.black),
                cursorColor: Colors.black,
                decoration: InputDecoration(
                  hintText: isArabic
                      ? 'ابحث عن مستخدمين، منشورات، كتب...'
                      : 'Search for users, posts, books...',
                  hintStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.black54),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear_rounded, color: Colors.black54),
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.muted.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: _isSearching
            ? Column(
                children: [
                  // ==============================================
                  // RESULTS COUNT
                  // ==============================================
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          isArabic
                              ? 'نتائج البحث: ${_filteredUsers.length + _filteredPosts.length + _filteredBooks.length + _filteredAdvertisements.length}'
                              : 'Results: ${_filteredUsers.length + _filteredPosts.length + _filteredBooks.length + _filteredAdvertisements.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.muted.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 4),

                  // ==============================================
                  // TABS
                  // ==============================================
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _SearchTabButton(
                          text: isArabic
                              ? 'الكل (${_filteredUsers.length + _filteredPosts.length + _filteredBooks.length + _filteredAdvertisements.length})'
                              : 'All (${_filteredUsers.length + _filteredPosts.length + _filteredBooks.length + _filteredAdvertisements.length})',
                          isSelected: _selectedTab == 0,
                          onTap: () {
                            setState(() {
                              _selectedTab = 0;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _SearchTabButton(
                          text: isArabic
                              ? 'مستخدمين (${_filteredUsers.length})'
                              : 'Users (${_filteredUsers.length})',
                          isSelected: _selectedTab == 1,
                          onTap: () {
                            setState(() {
                              _selectedTab = 1;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _SearchTabButton(
                          text: isArabic
                              ? 'منشورات (${_filteredPosts.length})'
                              : 'Posts (${_filteredPosts.length})',
                          isSelected: _selectedTab == 2,
                          onTap: () {
                            setState(() {
                              _selectedTab = 2;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _SearchTabButton(
                          text: isArabic
                              ? 'كتب (${_filteredBooks.length})'
                              : 'Books (${_filteredBooks.length})',
                          isSelected: _selectedTab == 3,
                          onTap: () {
                            setState(() {
                              _selectedTab = 3;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ==============================================
                  // RESULTS
                  // ==============================================
                  Expanded(
                    child: _selectedTab == 0
                        ? _buildAllResults(isArabic)
                        : _selectedTab == 1
                            ? _buildUserResults(isArabic)
                            : _selectedTab == 2
                                ? _buildPostResults(isArabic)
                                : _buildBookResults(isArabic),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 64,
                      color: AppTheme.muted.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isArabic
                          ? '🔍 ابحث عن أي شيء'
                          : '🔍 Search for anything',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppTheme.muted.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isArabic
                          ? 'مستخدمين، منشورات، كتب...'
                          : 'Users, posts, books...',
                      style: TextStyle(
                        color: AppTheme.muted.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================
  // BUILD ALL RESULTS
  // ============================================================

  Widget _buildAllResults(bool isArabic) {
    if (_searchError != null) {
      return _SearchErrorResult(isArabic: isArabic, onRetry: () => _performSearch(_searchController.text));
    }
    if (_filteredUsers.isEmpty &&
        _filteredPosts.isEmpty &&
        _filteredBooks.isEmpty && _filteredAdvertisements.isEmpty) {
      return _EmptyResult(isArabic);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_filteredAdvertisements.isNotEmpty) ...[
          Text(isArabic ? 'إعلانات ذات صلة' : 'Related ads',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ..._filteredAdvertisements.map((ad) => AdvertisementCard(ad: ad, isArabic: isArabic)),
          const SizedBox(height: 16),
        ],
        if (_filteredUsers.isNotEmpty) ...[
          Text(
            isArabic ? '👥 مستخدمين' : '👥 Users',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ..._filteredUsers.map((user) => _UserResultCard(user: user)),
          const SizedBox(height: 16),
        ],
        if (_filteredPosts.isNotEmpty) ...[
          Text(
            isArabic ? '📝 منشورات' : '📝 Posts',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ..._filteredPosts.map((post) => _PostResultCard(post: post, isArabic: isArabic)),
          const SizedBox(height: 16),
        ],
        if (_filteredBooks.isNotEmpty) ...[
          Text(
            isArabic ? '📚 كتب' : '📚 Books',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ..._filteredBooks.map((book) => _BookResultCard(book: book, isArabic: isArabic)),
        ],
      ],
    );
  }

  // ============================================================
  // BUILD USER RESULTS
  // ============================================================

  Widget _buildUserResults(bool isArabic) {
    if (_filteredUsers.isEmpty) {
      return _EmptyResult(isArabic);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        return _UserResultCard(user: _filteredUsers[index]);
      },
    );
  }

  // ============================================================
  // BUILD POST RESULTS
  // ============================================================

  Widget _buildPostResults(bool isArabic) {
    if (_filteredPosts.isEmpty) {
      return _EmptyResult(isArabic);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredPosts.length,
      itemBuilder: (context, index) {
        return _PostResultCard(post: _filteredPosts[index], isArabic: isArabic);
      },
    );
  }

  // ============================================================
  // BUILD BOOK RESULTS
  // ============================================================

  Widget _buildBookResults(bool isArabic) {
    if (_filteredBooks.isEmpty) {
      return _EmptyResult(isArabic);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredBooks.length,
      itemBuilder: (context, index) {
        return _BookResultCard(book: _filteredBooks[index], isArabic: isArabic);
      },
    );
  }
}

// ============================================================
// SEARCH TAB BUTTON
// ============================================================

class _SearchTabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _SearchTabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? AppTheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? AppTheme.primary
                  : AppTheme.muted.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// USER RESULT CARD
// ============================================================

class _UserResultCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _UserResultCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.muted.shade200,
        ),
      ),
      child: ListTile(
        leading: _SearchUserAvatar(user: user),
        title: Text(
          user['name']?.toString() ?? 'User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [user['department'], user['university']]
              .where((v) => v?.toString().trim().isNotEmpty == true)
              .map((v) => v.toString())
              .join(' • '),
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.muted.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: AppTheme.muted,
        ),
        onTap: () {
          final id = user['id']?.toString();
          if (id != null && id.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('👤 ${user['name']}'),
                backgroundColor: AppTheme.primary,
              ),
            );
          }
        },
      ),
    );
  }
}

class _SearchUserAvatar extends StatelessWidget {
  final Map<String, dynamic> user;

  const _SearchUserAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final image = user['profile_image']?.toString();
    final hasImage = image != null && image.isNotEmpty;
    return CircleAvatar(
      backgroundColor: AppTheme.primaryLight,
      backgroundImage: hasImage ? NetworkImage(image!) : null,
      child: hasImage
          ? null
          : const Icon(Icons.person_rounded, color: AppTheme.primaryDark),
    );
  }
}

// ============================================================
// POST RESULT CARD
// ============================================================

class _PostResultCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isArabic;

  const _PostResultCard({required this.post, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final primary = post[isArabic ? 'text_ar' : 'text_en']?.toString() ?? '';
    final fallback = post[isArabic ? 'text_en' : 'text_ar']?.toString() ?? '';
    final text = primary.trim().isNotEmpty ? primary : fallback;
    final users = post['users'];
    final author = users is Map && users['name']?.toString().trim().isNotEmpty == true
        ? users['name'].toString()
        : (isArabic ? 'زميل' : 'Colleague');
    final likes = (post['likes_count'] as num?)?.toInt() ?? 0;
    final preview = text.length > 90 ? '${text.substring(0, 90)}…' : text;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.muted.shade200),
      ),
      child: ListTile(
        leading: const Icon(Icons.description_rounded, color: AppTheme.primary),
        title: Text(preview, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(
          '✍️ $author • ❤️ $likes',
          style: TextStyle(fontSize: 12, color: AppTheme.muted.shade600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.muted),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CommentsScreen(post: Map<String, dynamic>.from(post))),
        ),
      ),
    );
  }
}

// ============================================================
// BOOK RESULT CARD
// ============================================================

class _BookResultCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final bool isArabic;

  const _BookResultCard({required this.book, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final title = book[isArabic ? 'title_ar' : 'title_en']?.toString() ?? book['title']?.toString() ?? '';
    final author = book[isArabic ? 'author_ar' : 'author_en']?.toString() ?? book['author']?.toString() ?? '';
    final subject = book[isArabic ? 'subject_ar' : 'subject_en']?.toString() ?? book['subject']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.muted.shade200),
      ),
      child: ListTile(
        leading: const Icon(Icons.menu_book_rounded, color: AppTheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          '✍️ $author • 📚 $subject',
          style: TextStyle(fontSize: 12, color: AppTheme.muted.shade600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.muted),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailsScreen(book: Map<String, dynamic>.from(book))),
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY RESULT
// ============================================================

class _SearchErrorResult extends StatelessWidget {
  final bool isArabic;
  final VoidCallback onRetry;

  const _SearchErrorResult({required this.isArabic, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 58, color: AppTheme.muted),
              const SizedBox(height: 12),
              Text(
                isArabic ? 'تعذر إكمال البحث الآن' : 'Search is temporarily unavailable',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyResult extends StatelessWidget {
  final bool isArabic;

  const _EmptyResult(this.isArabic);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppTheme.muted.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            isArabic ? '🔍 لا توجد نتائج' : '🔍 No results found',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.muted.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'حاول تغيير كلمات البحث'
                : 'Try changing your search terms',
            style: TextStyle(
              color: AppTheme.muted.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
