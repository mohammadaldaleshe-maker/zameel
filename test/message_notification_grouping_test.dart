import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/services/message_notification_grouping.dart';

void main() {
  test('two messages from one sender display once and retain both row IDs', () {
    final items = MessageNotificationGrouping.collapse([
      {'id': 'latest', 'type': 'message', 'actor_id': 'a',
        'data': {'conversation_id': 'c'}, 'is_read': true},
      {'id': 'older', 'type': 'message', 'actor_id': 'a',
        'data': {'conversation_id': 'c'}, 'is_read': false},
      {'id': 'other', 'type': 'message', 'actor_id': 'b',
        'data': {'conversation_id': 'c'}, 'is_read': false},
    ]);
    expect(items, hasLength(2));
    expect(items.first['_group_ids'], ['latest', 'older']);
    expect(items.first['is_read'], false);
    expect(items.last['_group_ids'], ['other']);
  });
}
