/// Server-filtered promotions are distributed among ordinary public posts.
/// Owners see their own active ads first; each identity appears only once.
List<Map<String, dynamic>> arrangeSponsoredFeed(
  List<Map<String, dynamic>> ordinary,
  List<Map<String, dynamic>> promotions,
  String? viewer,
) {
  final ads = {for (final row in promotions) '${row['id']}': row};
  final own = ads.values.where((r) => r['user_id'] == viewer).toList();
  final other = ads.values.where((r) => r['user_id'] != viewer).toList();
  final result = <Map<String, dynamic>>[...own];
  final seen = own.map((r) => '${r['id']}').toSet();
  var publicCount = 0;
  var adIndex = 0;
  for (final row in ordinary) {
    final id = '${row['id']}';
    if (ads.containsKey(id) || !seen.add(id)) continue;
    result.add(row);
    if ((row['audience'] ?? 'public') == 'public') publicCount++;
    if (publicCount == 5 && adIndex < other.length) {
      final ad = other[adIndex++];
      if (seen.add('${ad['id']}')) result.add(ad);
      publicCount = 0;
    }
  }
  return result;
}
