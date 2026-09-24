import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/services/call_invitation_guard.dart';

void main() {
  final now = DateTime.utc(2026, 9, 24, 20);
  final ringing = <String, dynamic>{
    'status': 'ringing',
    'callee_id': 'recipient',
    'created_at': now.subtract(const Duration(seconds: 30)).toIso8601String(),
  };

  test('only the recipient can answer a recent ringing call', () {
    expect(CallInvitationGuard.isCurrent(ringing, 'recipient', now), isTrue);
    expect(CallInvitationGuard.isCurrent(ringing, 'other', now), isFalse);
    expect(CallInvitationGuard.isCurrent({...ringing, 'status': 'ended'},
        'recipient', now), isFalse);
    expect(CallInvitationGuard.isCurrent({...ringing,
      'created_at': now.subtract(const Duration(minutes: 2)).toIso8601String(),
    }, 'recipient', now), isFalse);
  });
}
