String relativePostTime158(dynamic raw, {DateTime? now, bool arabic = true}) {
  final date = DateTime.tryParse(raw?.toString() ?? '');
  if (date == null) return '';
  final elapsed = (now ?? DateTime.now()).toUtc().difference(date.toUtc());
  final seconds = elapsed.inSeconds;
  if (seconds < 60) return arabic ? 'الآن' : 'Just now';
  final int count;
  final String unit;
  if (seconds < 3600) {
    count = elapsed.inMinutes;
    unit = 'minute';
  } else if (seconds < 86400) {
    count = elapsed.inHours;
    unit = 'hour';
  } else if (seconds < 2592000) {
    count = elapsed.inDays;
    unit = 'day';
  } else if (seconds < 31536000) {
    count = elapsed.inDays ~/ 30;
    unit = 'month';
  } else {
    count = elapsed.inDays ~/ 365;
    unit = 'year';
  }
  if (!arabic) return '$count $unit${count == 1 ? '' : 's'} ago';
  final forms = <String, List<String>>{
    'minute': ['دقيقة', 'دقيقتين', 'دقائق'],
    'hour': ['ساعة', 'ساعتين', 'ساعات'],
    'day': ['يوم', 'يومين', 'أيام'],
    'month': ['شهر', 'شهرين', 'أشهر'],
    'year': ['سنة', 'سنتين', 'سنوات'],
  }[unit]!;
  if (count == 1) return 'قبل ${forms[0]}';
  if (count == 2) return 'قبل ${forms[1]}';
  return 'قبل $count ${count <= 10 ? forms[2] : forms[0]}';
}

String jordanPostDate157(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty || value == 'null') return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return ''; // Never expose an unparsed database value.
  final jordan = parsed.toUtc().add(const Duration(hours: 3));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(jordan.day)}/${two(jordan.month)}/${jordan.year} · ${two(jordan.hour)}:${two(jordan.minute)}';
}

String postMetadata157(Map<String, dynamic> post, bool arabic, {DateTime? now}) {
  String clean(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    return text == 'null' ? '' : text;
  }

  final department = clean(post[arabic ? 'department_ar' : 'department_en']);
  final date = relativePostTime158(post['created_at'], arabic: arabic, now: now);
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
