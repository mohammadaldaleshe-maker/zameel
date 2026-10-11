String storyOwnerKey(Map<String, dynamic> story) {
  if (story['isMine'] == true) return '__me__';
  final id = story['user_id']?.toString().trim() ?? '';
  return id.isNotEmpty ? id : "name:${story['name'] ?? ''}";
}

List<List<Map<String, dynamic>>> orderedStoryGroups(
    List<Map<String, dynamic>> stories) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final story in stories) {
    groups.putIfAbsent(storyOwnerKey(story), () => []).add(story);
  }
  DateTime created(Map<String, dynamic> story) =>
      DateTime.tryParse('${story['created_at'] ?? ''}') ??
      DateTime.fromMillisecondsSinceEpoch(0);
  for (final group in groups.values) {
    group.sort((a, b) {
      final unseenA = a['viewed'] != true, unseenB = b['viewed'] != true;
      if (unseenA != unseenB) return unseenA ? -1 : 1;
      return created(b).compareTo(created(a));
    });
  }
  DateTime latest(List<Map<String, dynamic>> group) {
    final unseen = group.where((s) => s['viewed'] != true).toList();
    return (unseen.isEmpty ? group : unseen)
        .map(created)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  final rows = groups.values.toList();
  rows.sort((a, b) {
    final ownA = a.any((s) => s['isMine'] == true),
        ownB = b.any((s) => s['isMine'] == true);
    if (ownA != ownB) return ownA ? -1 : 1;
    final unseenA = a.any((s) => s['viewed'] != true),
        unseenB = b.any((s) => s['viewed'] != true);
    if (unseenA != unseenB) return unseenA ? -1 : 1;
    final date = latest(b).compareTo(latest(a));
    return date != 0
        ? date
        : storyOwnerKey(a.first).compareTo(storyOwnerKey(b.first));
  });
  return rows;
}
