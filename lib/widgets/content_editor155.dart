import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/post_publish_service.dart';
import '../services/secure_media_service.dart';

Future<Map<String, dynamic>?> editOwnedContent155(
    BuildContext context, String table, String id) async {
  final row = Map<String, dynamic>.from(await Supabase.instance.client
      .from(table)
      .select()
      .eq('id', id)
      .single());
  if (!context.mounted) return null;
  final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ContentEditor155(table: table, row: row));
  if (updated != null && table == 'posts')
    await SecureMediaService.resolvePost(updated);
  return updated;
}

class ContentEditor155 extends StatefulWidget {
  const ContentEditor155({super.key, required this.table, required this.row});
  final String table;
  final Map<String, dynamic> row;
  @override
  State<ContentEditor155> createState() => _ContentEditor155State();
}

class _ContentEditor155State extends State<ContentEditor155> {
  final fields = <String, TextEditingController>{};
  late List<Map<String, dynamic>> media;
  final picked = <PickedPostMedia>[];
  bool anonymous = false;
  bool busy = false;
  String? error;
  static const labels = {
    'title': 'العنوان',
    'name': 'الاسم',
    'notes': 'الملاحظات',
    'question': 'نص الاستطلاع',
    'event_date': 'التاريخ YYYY-MM-DD',
    'event_time': 'الوقت HH:mm',
    'starts_at': 'موعد البدء',
    'description': 'الوصف',
    'caption': 'الوصف',
    'content': 'النص',
    'body': 'النص',
    'text': 'النص',
    'text_ar': 'النص',
    'text_en': 'النص الإنجليزي',
    'price': 'السعر',
    'author': 'المؤلف',
    'condition': 'الحالة',
    'course': 'المساق',
    'place_name': 'اسم المكان'
  };
  @override
  void initState() {
    super.initState();
    anonymous = widget.row['is_anonymous'] == true;
    for (final k in labels.keys) {
      if (widget.row.containsKey(k))
        fields[k] =
            TextEditingController(text: widget.row[k]?.toString() ?? '');
    }
    media = (widget.row['media_items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (media.isEmpty)
      for (final type in ['image', 'video']) {
        final url = widget.row['${type}_url'];
        if (url != null && '$url'.isNotEmpty)
          media.add({'type': type, 'url': url});
      }
  }

  @override
  void dispose() {
    for (final c in fields.values) c.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final changes = <String, dynamic>{
        if (widget.row.containsKey('is_anonymous')) 'is_anonymous': anonymous,
        for (final e in fields.entries)
          e.key: e.key == 'price'
              ? num.tryParse(e.value.text)
              : e.key == 'event_time' && e.value.text.trim().isEmpty
                  ? null
                  : e.value.text.trim()
      };
      if (widget.table == 'posts' || widget.table == 'clips') {
        final added =
            await PostPublishService.uploadForEdit155(widget.row, picked);
        final all = [...media, ...added];
        if (widget.table == 'clips' &&
            (all.length != 1 || all.first['type'] != 'video'))
          throw StateError('الشورت يحتاج فيديو واحدًا');
        if (widget.table == 'posts') changes['media_items'] = all;
        for (final type in ['image', 'video']) {
          final match = all.where((m) => m['type'] == type);
          if (widget.row.containsKey('${type}_url'))
            changes['${type}_url'] = match.isEmpty ? null : match.first['url'];
        }
      }
      final updated = await Supabase.instance.client
          .rpc('zameel_edit_content_155', params: {
        'p_table': widget.table,
        'p_id': widget.row['id'],
        'p_changes': changes
      });
      if (mounted)
        Navigator.pop(context, Map<String, dynamic>.from(updated as Map));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: AlertDialog(
          title: const Text('تعديل المحتوى'),
          content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.row.containsKey('is_anonymous'))
                  SwitchListTile(
                      title: const Text('نشر مجهول'),
                      value: anonymous,
                      onChanged:
                          busy ? null : (v) => setState(() => anonymous = v)),
                for (final e in fields.entries)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                          controller: e.value,
                          enabled: !busy,
                          minLines: 1,
                          maxLines: e.key == 'price' ? 1 : 4,
                          decoration:
                              InputDecoration(labelText: labels[e.key]))),
                if (widget.table == 'posts' || widget.table == 'clips') ...[
                  for (var i = 0; i < media.length; i++)
                    ListTile(
                        title: Text(
                            '${media[i]['type'] == 'video' ? 'فيديو' : 'صورة'} ${i + 1}'),
                        trailing: IconButton(
                            onPressed: busy
                                ? null
                                : () => setState(() => media.removeAt(i)),
                            icon: const Icon(Icons.delete_outline))),
                  for (var i = 0; i < picked.length; i++)
                    ListTile(
                        title: Text(picked[i].name),
                        trailing: IconButton(
                            onPressed: busy
                                ? null
                                : () => setState(() => picked.removeAt(i)),
                            icon: const Icon(Icons.close))),
                  TextButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final limit = (widget.table == 'clips' ? 1 : 10) -
                                  media.length -
                                  picked.length;
                              if (limit <= 0) {
                                setState(() => error = 'احذف وسيطًا لاستبداله');
                                return;
                              }
                              final files = widget.table == 'clips'
                                  ? await PostPublishService.pickMultipleVideos(
                                      limit: 1)
                                  : await PostPublishService.pickMultipleMedia(
                                      limit: limit);
                              if (mounted) setState(() => picked.addAll(files));
                            },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(widget.table == 'clips'
                          ? 'إضافة فيديو بديل'
                          : 'إضافة صور وفيديوهات'))
                ],
                if (error != null)
                  Text(error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error))
              ]))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'جارٍ الحفظ…' : 'حفظ التعديل'))
          ]));
}

class MyContent155 extends StatefulWidget {
  const MyContent155({super.key});
  @override
  State<MyContent155> createState() => _MyContent155State();
}

class _MyContent155State extends State<MyContent155> {
  static const kinds = {
    'posts': ['المنشورات', 'user_id'],
    'calendar_events': ['المواعيد والأحداث', 'owner_id'],
    'community_groups': ['مجموعاتي', 'owner_id'],
    'social_lammas': ['لمة التي أنشأتها', 'creator_id'],
    'polls': ['استطلاعاتي', 'creator_id'],
    'clips': ['الشورتس', 'user_id'],
    'messages': ['الرسائل الخاصة', 'sender_id'],
    'community_group_messages': ['رسائل المجموعات', 'user_id'],
    'social_lamma_messages': ['رسائل لمة', 'sender_id'],
    'community_messages': ['رسائل المجتمع', 'user_id'],
    'zameel_anonymous_messages': ['الرسائل المجهولة', 'sender_id'],
    'social_stories': ['القصص', 'user_id'],
    'book_listings': ['إعلانات الكتب', 'owner_id'],
    'study_files': ['الملفات الدراسية', 'user_id'],
    'zameel_radio_posts': ['الراديو', 'user_id'],
    'zameel_college_entries': ['تحدي الكلية', 'user_id']
  };
  String table = 'posts';
  int page = 0;
  List<Map<String, dynamic>> rows = [];
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final current = table;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) throw StateError('سجّل الدخول');
      final data = await Supabase.instance.client
          .from(table)
          .select()
          .eq(kinds[table]![1], uid)
          .order('created_at', ascending: false)
          .range(page * 30, page * 30 + 29);
      if (mounted && table == current)
        setState(() {
          rows = List<Map<String, dynamic>>.from(data);
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('تعديل محتواي')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
                initialValue: table,
                items: [
                  for (final e in kinds.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value[0]))
                ],
                onChanged: loading
                    ? null
                    : (v) {
                        setState(() {
                          table = v!;
                          page = 0;
                        });
                        load();
                      })),
        if (error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      final text = [
                        'title',
                        'name',
                        'question',
                        'notes',
                        'caption',
                        'text_ar',
                        'body',
                        'content',
                        'description'
                      ].map((k) => row[k]?.toString() ?? '').firstWhere(
                          (v) => v.isNotEmpty,
                          orElse: () => 'محتوى ${i + 1}');
                      return ListTile(
                          title: Text(text,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              '${row['created_at'] ?? ''}${row['edited_at'] != null ? ' • تم التعديل' : ''}'),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () async {
                            try {
                              final result = await editOwnedContent155(
                                  context, table, '${row['id']}');
                              if (result != null && mounted)
                                setState(() => row.addAll(result));
                            } catch (e) {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$e')));
                            }
                          });
                    })),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          TextButton(
              onPressed: loading || page == 0
                  ? null
                  : () {
                      page--;
                      load();
                    },
              child: const Text('السابق')),
          Text('صفحة ${page + 1}'),
          TextButton(
              onPressed: loading || rows.length < 30
                  ? null
                  : () {
                      page++;
                      load();
                    },
              child: const Text('التالي'))
        ])
      ]));
}
