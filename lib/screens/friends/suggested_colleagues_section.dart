import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../services/colleague_suggestion_service.dart';
import '../profile/profile_screen.dart';

class SuggestedColleaguesSection extends StatefulWidget {
  const SuggestedColleaguesSection({super.key});

  @override
  State<SuggestedColleaguesSection> createState() => _SuggestedColleaguesSectionState();
}

class _SuggestedColleaguesSectionState extends State<SuggestedColleaguesSection> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load([String searchText = '']) async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await ColleagueSuggestionService.suggestions(searchText: searchText);
      if (mounted) setState(() => _items = rows);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(Map<String, dynamic> item) async {
    try {
      await ColleagueSuggestionService.sendRequest(item['user_id']?.toString() ?? '');
      if (mounted) setState(() => item['request_status'] = 'pending');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال طلب الزمالة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) return const SizedBox(height: 96, child: Center(child: CircularProgressIndicator()));
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.group_add_outlined, color: AppTheme.primary), SizedBox(width: 8), Text('زملاء مقترحون', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))]),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: _load,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'ابحث عن زملاء آخرين', suffixIcon: IconButton(onPressed: () => _load(_search.text), icon: const Icon(Icons.arrow_forward)), isDense: true, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          if (_items.isEmpty)
            const Padding(padding: EdgeInsets.all(10), child: Text('لا توجد اقتراحات جديدة حاليًا.'))
          else
            SizedBox(
              height: 158,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final u = _items[i];
                  final image = u['profile_image']?.toString();
                  final pending = u['request_status'] == 'pending';
                  return SizedBox(width: 126, child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: u['user_id']?.toString()))),
                    child: Column(children: [
                      CircleAvatar(radius: 31, backgroundImage: image != null && image.isNotEmpty ? NetworkImage(image) : null, child: image == null || image.isEmpty ? const Icon(Icons.person, size: 30) : null),
                      const SizedBox(height: 5),
                      Text(u['name']?.toString() ?? 'زميل', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(u['match_reason']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      const SizedBox(height: 5),
                      SizedBox(width: double.infinity, height: 31, child: FilledButton.tonal(onPressed: pending ? null : () => _add(u), child: Text(pending ? 'تم الإرسال' : 'إضافة', style: const TextStyle(fontSize: 11)))),
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
