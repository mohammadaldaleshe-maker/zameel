import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/remaining_services.dart';
import 'comments/comments_screen.dart';
import 'package:zameel/theme/app_theme.dart';
import '../widgets/post_media_gallery.dart';

class SavedPostsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedPosts;

  const SavedPostsScreen({
    super.key,
    required this.savedPosts,
  });

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  late List<Map<String, dynamic>> _savedPosts;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _savedPosts = List<Map<String, dynamic>>.from(widget.savedPosts);
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await RemainingServices.savedPosts();
      if (!mounted) return;
      setState(() {
        _savedPosts = rows;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unsave(Map<String, dynamic> post, bool isArabic) async {
    final id = post['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await RemainingServices.unsavePost(id);
      if (!mounted) return;
      setState(() => _savedPosts.removeWhere((item) => item['id']?.toString() == id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? '🗑️ تم إلغاء الحفظ' : '🗑️ Removed from saved'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تعذر إلغاء الحفظ' : 'Could not remove saved post')),
      );
    }
  }

  String _author(Map<String, dynamic> post) {
    final user = post['users'];
    if (user is Map) {
      final name = user['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    return post['name_ar']?.toString() ?? post['name_en']?.toString() ?? 'زميل';
  }

  String _text(Map<String, dynamic> post, bool isArabic) {
    final primary = post[isArabic ? 'text_ar' : 'text_en']?.toString() ?? '';
    if (primary.trim().isNotEmpty) return primary;
    return post[isArabic ? 'text_en' : 'text_ar']?.toString() ?? '';
  }

  String _time(Map<String, dynamic> post, bool isArabic) {
    final created = DateTime.tryParse(post['created_at']?.toString() ?? '')?.toLocal();
    if (created == null) {
      return post[isArabic ? 'time_ar' : 'time_en']?.toString() ?? '';
    }
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return isArabic ? 'الآن' : 'Now';
    if (diff.inHours < 1) return isArabic ? 'منذ ${diff.inMinutes} د' : '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return isArabic ? 'منذ ${diff.inHours} س' : '${diff.inHours}h ago';
    return isArabic ? 'منذ ${diff.inDays} ي' : '${diff.inDays}d ago';
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
            isArabic ? '📑 المحفوظات' : '📑 Saved Posts',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _savedPosts.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 170),
                          Icon(
                            Icons.bookmark_border_rounded,
                            size: 64,
                            color: AppTheme.muted.shade400,
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              isArabic ? '📭 لا توجد منشورات محفوظة' : '📭 No saved posts',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppTheme.muted.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: _savedPosts.length,
                        itemBuilder: (context, index) {
                          final post = _savedPosts[index];
                          final rawMedia = post['media_items'];
                          final hasOrderedMedia = rawMedia is List && rawMedia.isNotEmpty;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CommentsScreen(post: Map<String, dynamic>.from(post))),
                            ),
                            child: Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppTheme.muted.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppTheme.primaryLight,
                                        child: Icon(
                                          Icons.person_rounded,
                                          color: AppTheme.primaryDark,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _author(post),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            Text(
                                              _time(post, isArabic),
                                              style: TextStyle(fontSize: 11, color: AppTheme.muted.shade500),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _unsave(post, isArabic),
                                        icon: const Icon(Icons.bookmark_rounded, color: AppTheme.primary, size: 22),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (_text(post, isArabic).trim().isNotEmpty)
                                    Text(
                                      _text(post, isArabic),
                                      style: const TextStyle(fontSize: 15, height: 1.5),
                                    ),
                                  if (hasOrderedMedia) ...[
                                    const SizedBox(height: 10),
                                    PostMediaGallery(post: post, height: 200),
                                  ],
                                ],
                              ),
                            ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
