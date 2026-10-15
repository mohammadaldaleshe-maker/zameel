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

/// One frozen batch across both campaign types, without duplicate placements.
List<Map<String, dynamic>> arrangeCampaignFeed162(
  List<Map<String, dynamic>> ordinary,
  List<Map<String, dynamic>> promotions,
  List<Map<String, dynamic>> partnerAds, {
  List<String> order = const [],
}) {
  final queue = <Map<String, dynamic>>[];
  final ids = <String>{};
  for (var i = 0; i < promotions.length || i < partnerAds.length; i++) {
    if (i < promotions.length && ids.add('post:${promotions[i]['id']}')) {
      queue.add(promotions[i]);
    }
    if (i < partnerAds.length && ids.add('ad:${partnerAds[i]['id']}')) {
      queue.add({...partnerAds[i], '_partner_campaign162': true});
    }
  }
  if (order.isNotEmpty) {
    final ranks = {for (var i = 0; i < order.length; i++) order[i]: i};
    String identity(Map<String, dynamic> row) =>
        '${row['_partner_campaign162'] == true ? 'ad' : 'post'}:${row['id']}';
    queue.sort((a, b) => (ranks[identity(a)] ?? order.length)
        .compareTo(ranks[identity(b)] ?? order.length));
  }
  final postAds = promotions.map((r) => '${r['id']}').toSet();
  final result = <Map<String, dynamic>>[];
  final ordinarySeen = <String>{};
  var count = 0, next = 0;
  for (final post in ordinary) {
    if (postAds.contains('${post['id']}') || !ordinarySeen.add('${post['id']}'))
      continue;
    result.add(post);
    if (++count % 6 == 0 && next < queue.length) result.add(queue[next++]);
  }
  while (next < queue.length) {
    result.add(queue[next++]);
  }
  return result;
}
