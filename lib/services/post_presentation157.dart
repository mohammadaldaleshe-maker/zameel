String jordanPostDate157(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty || value == 'null') return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return ''; // Never expose an unparsed database value.
  final jordan = parsed.toUtc().add(const Duration(hours: 3));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(jordan.day)}/${two(jordan.month)}/${jordan.year} · ${two(jordan.hour)}:${two(jordan.minute)}';
}

String postMetadata157(Map<String, dynamic> post, bool arabic) {
  String clean(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    return text == 'null' ? '' : text;
  }

  final department = clean(post[arabic ? 'department_ar' : 'department_en']);
  final date = jordanPostDate157(post['created_at']);
  final existing = clean(post[arabic ? 'time_ar' : 'time_en']);
  return [department, date.isNotEmpty ? date : existing]
      .where((part) => part.isNotEmpty)
      .join(' · ');
}

bool completedMediaPost157(Map<String, dynamic> post) {
  if (post['upload_state156'] != 'ready') return false;
  final type = post['type'];
  if (type != 'image' && type != 'video') return true;
  bool valid(dynamic value) =>
      value is String &&
      value.trim().isNotEmpty &&
      !value.startsWith('uploading://');
  final items = post['media_items'];
  return (items is List &&
          items.any((item) =>
              item is Map && item['type'] == type && valid(item['url']))) ||
      valid(post[type == 'video' ? 'video_url' : 'image_url']);
}
