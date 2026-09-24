/// Presents one notification per conversation and sender while retaining the
/// underlying row IDs so opening it marks every grouped message as read.
class MessageNotificationGrouping {
  static List<Map<String, dynamic>> collapse(
      Iterable<Map<String, dynamic>> notifications) {
    final items = <Map<String, dynamic>>[];
    final conversations = <String, Map<String, dynamic>>{};
    for (final original in notifications) {
      final row = Map<String, dynamic>.from(original);
      final raw = row['data'];
      final data = raw is Map ? raw : const <String, dynamic>{};
      final conversation = data['conversation_id']?.toString() ?? '';
      final sender = row['actor_id']?.toString() ?? data['sender_id']?.toString() ?? '';
      if (row['type'] != 'message' || conversation.isEmpty || sender.isEmpty) {
        items.add(row);
        continue;
      }
      final key = '$conversation:$sender';
      final existing = conversations[key];
      if (existing == null) {
        row['_group_ids'] = <String>[row['id'].toString()];
        row['_message_count'] = 1;
        conversations[key] = row;
        items.add(row);
      } else {
        (existing['_group_ids'] as List<String>).add(row['id'].toString());
        existing['_message_count'] = (existing['_message_count'] as int) + 1;
        if (row['is_read'] == false) existing['is_read'] = false;
      }
    }
    return items;
  }
}
