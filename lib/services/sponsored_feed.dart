import 'dart:math';

/// Ads are already audience-filtered by the server. Stable within one feed
/// load; a newly loaded promotion batch rotates the order for every viewer.
List<Map<String, dynamic>> arrangeSponsoredFeed(
  List<Map<String, dynamic>> ordinary,
  List<Map<String, dynamic>> promotions,
  String? viewer,
) {
  final ads = {for (final row in promotions) '${row['id']}': row};
  final queue = ads.values.toList();
  final result = <Map<String, dynamic>>[];
  final seen = <String>{};
  var publicCount = 0;
  var adIndex = 0;
  for (final row in ordinary) {
    final id = '${row['id']}';
    if (ads.containsKey(id) || !seen.add(id)) continue;
    result.add(row);
    if ((row['audience'] ?? 'public') == 'public') publicCount++;
    if (publicCount == 5) {
      if (adIndex < queue.length) {
        final ad = queue[adIndex++];
        if (seen.add('${ad['id']}')) result.add(ad);
      }
      publicCount = 0;
    }
  }
  return result;
}

void shuffleSponsoredBatch(List<Map<String, dynamic>> rows) =>
    rows.shuffle(Random());
