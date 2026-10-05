import 'package:zameel/theme/appearance_controller.dart';
import 'package:zameel/widgets/verified_name.dart';
import 'package:flutter/material.dart';
import '../../widgets/cached_media_image.dart';
import '../../services/media_cache_service.dart';

import '../../theme/app_theme.dart';
import '../../services/colleague_suggestion_service.dart';
import '../profile/profile_screen.dart';

class SuggestedColleaguesSection extends StatefulWidget {
  const SuggestedColleaguesSection({super.key});

  @override
  State<SuggestedColleaguesSection> createState() =>
      _SuggestedColleaguesSectionState();
}

class _SuggestedColleaguesSectionState extends State<SuggestedColleaguesSection>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
      _restore();
    });
  }

  Future<void> _restore() async {
    final version = _loadVersion;
    final rows = await ColleagueSuggestionService.recentSuggestions();
    if (mounted &&
        _loading &&
        version == _loadVersion &&
        _search.text.isEmpty &&
        _items.isEmpty &&
        rows.isNotEmpty) {
      setState(() => _items = rows);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load([String searchText = '']) async {
    final version = ++_loadVersion;
    if (mounted) setState(() => _loading = true);
    try {
      final rows =
          await ColleagueSuggestionService.suggestions(
              searchText: searchText, includeDeviceSignals: false);
      if (mounted && version == _loadVersion) {
        setState(() => _items = rows);
        MediaCacheService.prefetch(
            rows.take(4).map((row) => row['profile_image']?.toString() ?? ''),
            limit: 4);
      }
      // The scrolling feed uses backend ranking and already-cached signals.
      // Native contact reads belong to the explicit colleagues screen.
    } catch (_) {
      // A transient refresh failure should not erase visible suggestions.
      if (mounted && version == _loadVersion && _items.isEmpty) {
        setState(() => _items = const []);
      }
    } finally {
      if (mounted && version == _loadVersion) setState(() => _loading = false);
    }
  }

  Future<void> _add(Map<String, dynamic> item) async {
    try {
      await ColleagueSuggestionService.sendRequest(
          item['user_id']?.toString() ?? '');
      if (mounted) setState(() => item['request_status'] = 'pending');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر إرسال طلب الزمالة: $e')));
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    AppearanceScope.observe(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.group_add_outlined, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('زملاء مقترحون',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: _load,
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'ابحث عن زملاء آخرين',
                suffixIcon: IconButton(
                    onPressed: () => _load(_search.text),
                    icon: const Icon(Icons.arrow_forward)),
                isDense: true,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 158,
            child: _items.isEmpty
                ? Center(
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: LinearProgressIndicator())
                        : const Text('لا توجد اقتراحات جديدة حاليًا.'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final u = _items[i];
                      final image = u['profile_image']?.toString();
                      final pending = u['request_status'] == 'pending';
                      return SizedBox(
                          width: 126,
                          child: InkWell(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ProfileScreen(
                                        userId: u['user_id']?.toString()))),
                            child: Column(children: [
                              ClipOval(
                                  child: SizedBox(
                                      width: 62,
                                      height: 62,
                                      child: image != null && image.isNotEmpty
                                          ? CachedMediaImage(
                                              url: image,
                                              fit: BoxFit.cover,
                                              cacheWidth: 200,
                                              fallback: const Icon(Icons.person,
                                                  size: 30))
                                          : const Icon(Icons.person,
                                              size: 30))),
                              const SizedBox(height: 5),
                              VerifiedName(
                                  userId: (u['id'] ?? u['user_id'])?.toString(),
                                  child: Text(u['name']?.toString() ?? 'زميل',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800))),
                              Text(u['match_reason']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.adaptiveSecondary)),
                              const SizedBox(height: 5),
                              SizedBox(
                                  width: double.infinity,
                                  height: 31,
                                  child: FilledButton.tonal(
                                      onPressed: pending ? null : () => _add(u),
                                      child: Text(
                                          pending ? 'تم الإرسال' : 'إضافة',
                                          style:
                                              const TextStyle(fontSize: 11)))),
                            ]),
                          ));
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
