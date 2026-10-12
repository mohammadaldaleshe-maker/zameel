/// Resolve only media attached to this post; missing media has no sample fallback.
String postVideoReference156(Map<String, dynamic> post) {
  // A mixed-media viewer explicitly selects one item. Never switch it to
  // another video from the same post when its selected reference is missing.
  if (post['media_index'] is int) {
    final selected = post['video_url'];
    return selected is String ? selected.trim() : '';
  }
  final raw = post['media_items'];
  if (raw is List) {
    for (final item in raw) {
      if (item is Map && item['type']?.toString().toLowerCase() == 'video') {
        final value = item['url'];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
  }
  for (final key in ['video_url', 'videoUrl']) {
    final value = post[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}
