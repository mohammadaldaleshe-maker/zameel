/// Preserve the server delivery order and insert one sponsored card after
/// every six ordinary posts. Duplicate posts never create extra placements.
List<Map<String, dynamic>> arrangeSponsoredFeed(
  List<Map<String, dynamic>> ordinary,
  List<Map<String, dynamic>> promotions,
  String? viewer,
) {
  final ads = {for (final row in promotions) '${row['id']}': row};
  final queue = ads.values.toList();
  final result = <Map<String, dynamic>>[];
  final seen = <String>{};
  var ordinaryCount = 0;
  var adIndex = 0;
  for (final row in ordinary) {
    final id = '${row['id']}';
    if (ads.containsKey(id) || !seen.add(id)) continue;
    result.add(row);
    ordinaryCount++;
    if (ordinaryCount == 6) {
      if (adIndex < queue.length) {
        final ad = queue[adIndex++];
        if (seen.add('${ad['id']}')) result.add(ad);
      }
      ordinaryCount = 0;
    }
  }
  return result;
}
