import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../../l10n/translations.dart';
import '../profile/profile_screen.dart';

// ============================================================
// ADVANCED SEARCH SCREEN
// ============================================================

// مستخدمو زميل التجريبيون
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

  // المستخدمون التجريبيون: تبقى موجودة بجانب المستخدمين الحقيقيين.
  final List<Map<String, dynamic>> _users = [
    {'name': 'ليان الخطيب','department':'علوم الحاسوب','university':'الجامعة الأردنية','isDemo': true},
    {'name':'آدم الحوراني','department':'هندسة البرمجيات','university':'جامعة العلوم والتكنولوجيا الأردنية','isDemo': true},
    {'name':'نور العزام','department':'إدارة الأعمال','university':'الجامعة الهاشمية','isDemo': true},
    {'name':'يوسف الشديفات','department':'الهندسة المدنية','university':'جامعة اليرموك','isDemo': true},
    {'name':'رؤى المومني','department':'الصيدلة','university':'جامعة العلوم التطبيقية الخاصة','isDemo': true},
  ];

  final List<Map<String, dynamic>> _posts = [
    {'text': 'شرح سريع لفكرة مهمة في قواعد البيانات 📚', 'author': 'محمد أحمد', 'likes': 128},
    {'text': 'يا جماعة، هل يوجد أحد لديه ملخص مرتب للفصل الرابع؟', 'author': 'سارة علي', 'likes': 44},
    {'text': 'تم رفع ملخص مادة البرمجة على المجموعة', 'author': 'أحمد خالد', 'likes': 67},
  ];

  final List<Map<String, dynamic>> _books = [
    {'title': 'مقدمة في قواعد البيانات', 'author': 'د. أحمد العلي', 'subject': 'قواعد البيانات'},
    {'title': 'هندسة البرمجيات', 'author': 'د. محمد سعيد', 'subject': 'هندسة البرمجيات'},
    {'title': 'الرياضيات المتقدمة', 'author': 'د. خالد الحسين', 'subject': 'الرياضيات'},
  ];

  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _filteredPosts = [];
  List<Map<String, dynamic>> _filteredBooks = [];
  bool _isSearching = false;
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
        _isSearching = false;
      });
      return;
    }

    final rawQuery = query.trim();
    final normalized = rawQuery.toLowerCase();

    setState(() => _isSearching = true);

    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final db = Supabase.instance.client;
        final currentId = db.auth.currentUser?.id;

        // Search real users from Supabase first. RLS still controls which
        // profiles are visible according to the app's privacy rules.
        final response = await db
            .from('users')
            .select('id,name,university,college,department,profile_image')
            .limit(500);

        final realUsers = List<Map<String, dynamic>>.from(response)
            .where((u) => currentId == null || u['id']?.toString() != currentId)
            .where((u) {
              final haystack = [
                u['name'],
                u['university'],
                u['college'],
                u['department'],
              ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');
              return haystack.contains(normalized);
            })
            .map((u) => {...u, 'isDemo': false})
            .toList();

        final demoUsers = _users.where((u) {
          final haystack = [u['name'], u['department'], u['university']]
              .map((v) => v.toString().toLowerCase())
              .join(' ');
          return haystack.contains(normalized);
        }).toList();

        final byId = <String, Map<String, dynamic>>{};
        for (final user in realUsers) {
          final id = user['id']?.toString();
          if (id != null && id.isNotEmpty) byId[id] = user;
        }

        final mergedUsers = <Map<String, dynamic>>[...byId.values, ...demoUsers];

        final filteredPosts = _posts.where((post) {
          final haystack = [post['text'], post['author']]
              .map((v) => v.toString().toLowerCase())
              .join(' ');
          return haystack.contains(normalized);
        }).toList();

        final filteredBooks = _books.where((book) {
          final haystack = [book['title'], book['author'], book['subject']]
              .map((v) => v.toString().toLowerCase())
              .join(' ');
          return haystack.contains(normalized);
        }).toList();

        if (!mounted) return;
        setState(() {
          _filteredUsers = mergedUsers;
          _filteredPosts = filteredPosts;
          _filteredBooks = filteredBooks;
          _isSearching = true;
        });
      } catch (e) {
        // Keep demo/search results available even when the network is down.
        final demoUsers = _users.where((u) {
          final haystack = [u['name'], u['department'], u['university']]
              .map((v) => v.toString().toLowerCase())
              .join(' ');
          return haystack.contains(normalized);
        }).toList();

        if (!mounted) return;
        setState(() {
          _filteredUsers = demoUsers;
          _filteredPosts = _posts.where((post) =>
              [post['text'], post['author']].map((v) => v.toString().toLowerCase()).join(' ').contains(normalized)).toList();
          _filteredBooks = _books.where((book) =>
              [book['title'], book['author'], book['subject']].map((v) => v.toString().toLowerCase()).join(' ').contains(normalized)).toList();
          _isSearching = true;
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
      _isSearching = false;
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
                decoration: InputDecoration(
                  hintText: isArabic
                      ? 'ابحث عن مستخدمين، منشورات، كتب...'
                      : 'Search for users, posts, books...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear_rounded),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
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
                              ? 'نتائج البحث: ${_filteredUsers.length + _filteredPosts.length + _filteredBooks.length}'
                              : 'Results: ${_filteredUsers.length + _filteredPosts.length + _filteredBooks.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
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
                              ? 'الكل (${_filteredUsers.length + _filteredPosts.length + _filteredBooks.length})'
                              : 'All (${_filteredUsers.length + _filteredPosts.length + _filteredBooks.length})',
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
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isArabic
                          ? '🔍 ابحث عن أي شيء'
                          : '🔍 Search for anything',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isArabic
                          ? 'مستخدمين، منشورات، كتب...'
                          : 'Users, posts, books...',
                      style: TextStyle(
                        color: Colors.grey.shade500,
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
    if (_filteredUsers.isEmpty &&
        _filteredPosts.isEmpty &&
        _filteredBooks.isEmpty) {
      return _EmptyResult(isArabic);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
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
          ..._filteredPosts.map((post) => _PostResultCard(post: post)),
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
          ..._filteredBooks.map((book) => _BookResultCard(book: book)),
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
        return _PostResultCard(post: _filteredPosts[index]);
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
        return _BookResultCard(book: _filteredBooks[index]);
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
                    ? const Color(0xFF18D3C3)
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
                  ? const Color(0xFF18D3C3)
                  : Colors.grey.shade600,
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
          color: Colors.grey.shade200,
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
            color: Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          final id = user['id']?.toString();
          if (id != null && id.isNotEmpty && user['isDemo'] != true) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('👤 ${user['name']}'),
                backgroundColor: const Color(0xFF18D3C3),
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
    final hasImage = image != null && image.isNotEmpty && user['isDemo'] != true;
    return CircleAvatar(
      backgroundColor: const Color(0xFFDDF6F3),
      backgroundImage: hasImage ? NetworkImage(image!) : null,
      child: hasImage
          ? null
          : const Icon(Icons.person_rounded, color: Color(0xFF0B9F95)),
    );
  }
}

// ============================================================
// POST RESULT CARD
// ============================================================

class _PostResultCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _PostResultCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.description_rounded,
          color: Color(0xFF18D3C3),
        ),
        title: Text(
          post['text'].length > 50
              ? '${post['text'].substring(0, 50)}...'
              : post['text'],
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '✍️ ${post['author']} • ❤️ ${post['likes']}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📝 عرض المنشور'),
              backgroundColor: Color(0xFF18D3C3),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// BOOK RESULT CARD
// ============================================================

class _BookResultCard extends StatelessWidget {
  final Map<String, dynamic> book;

  const _BookResultCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.menu_book_rounded,
          color: Color(0xFF18D3C3),
        ),
        title: Text(
          book['title'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '✍️ ${book['author']} • 📚 ${book['subject']}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📖 عرض كتاب ${book['title']}'),
              backgroundColor: const Color(0xFF18D3C3),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// EMPTY RESULT
// ============================================================

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
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            isArabic ? '🔍 لا توجد نتائج' : '🔍 No results found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'حاول تغيير كلمات البحث'
                : 'Try changing your search terms',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}