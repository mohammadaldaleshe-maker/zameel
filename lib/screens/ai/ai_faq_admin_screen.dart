import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/theme/app_theme.dart';

class AIFaqAdminScreen extends StatefulWidget {
  const AIFaqAdminScreen({super.key});

  @override
  State<AIFaqAdminScreen> createState() => _AIFaqAdminScreenState();
}

class _AIFaqAdminScreenState extends State<AIFaqAdminScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _client
          .from('ai_faq_entries')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _items = (rows as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? current]) async {
    final question =
        TextEditingController(text: current?['question_ar']?.toString());
    final answer =
        TextEditingController(text: current?['answer_ar']?.toString());
    final keywords = TextEditingController(
      text: current?['keywords'] is List
          ? (current!['keywords'] as List).join('، ')
          : '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(current == null ? 'إضافة سؤال معتمد' : 'تعديل السؤال'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: question,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'السؤال'),
              ),
              TextField(
                controller: answer,
                maxLines: 5,
                decoration:
                    const InputDecoration(labelText: 'الإجابة المعتمدة'),
              ),
              TextField(
                controller: keywords,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'صيغ قريبة، مفصولة بفاصلة',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              if (question.text.trim().isEmpty || answer.text.trim().isEmpty) {
                return;
              }
              final values = {
                'question_ar': question.text.trim(),
                'answer_ar': answer.text.trim(),
                'keywords': keywords.text
                    .split(RegExp(r'[,،\n]'))
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList(),
                'is_active': true,
                'updated_at': DateTime.now().toIso8601String(),
                if (current == null) 'created_by': _client.auth.currentUser?.id,
              };
              if (current == null) {
                await _client.from('ai_faq_entries').insert(values);
              } else {
                await _client
                    .from('ai_faq_entries')
                    .update(values)
                    .eq('id', current['id']);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    question.dispose();
    answer.dispose();
    keywords.dispose();
    if (saved == true) await _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    await _client.from('ai_faq_entries').delete().eq('id', item['id']);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('أسئلة Zameel AI المعتمدة')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _edit,
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة سؤال'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('لا توجد أسئلة معتمدة بعد'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        child: ListTile(
                          title: Text(item['question_ar']?.toString() ?? ''),
                          subtitle: Text(
                            item['answer_ar']?.toString() ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: Icon(Icons.verified_rounded,
                              color: AppTheme.primary),
                          onTap: () => _edit(item),
                          trailing: IconButton(
                            tooltip: 'حذف',
                            onPressed: () => _delete(item),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
