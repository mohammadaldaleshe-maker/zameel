import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/services/jordan_phone.dart';
import 'package:zameel/services/sponsored_feed.dart';

void main() {
  test(
      'Jordan mobile local and international formats share one canonical value',
      () {
    for (final prefix in ['77', '78', '79']) {
      final canonical = '+962${prefix}0123456';
      expect(normalizeJordanMobile('0${prefix}0123456'), canonical);
      expect(normalizeJordanMobile('00962${prefix}0123456'), canonical);
      expect(normalizeJordanMobile(canonical), canonical);
    }
    for (final invalid in [
      '',
      '079123',
      '+962760123456',
      '07901234567',
      'abc0790123456',
      '+9620790123456'
    ]) {
      expect(normalizeJordanMobile(invalid), isNull, reason: invalid);
    }
  });
  test(
      'server candidates follow every six ordinary posts including private rows',
      () {
    final ordinary = [
      {'id': 'private', 'audience': 'friends'},
      for (var i = 0; i < 12; i++) {'id': 'p$i', 'audience': 'public'}
    ];
    final ads = [
      {'id': 'owner-ad', 'user_id': 'me'},
      {'id': 'other-ad', 'user_id': 'other'}
    ];
    final result = arrangeSponsoredFeed(ordinary, ads, 'me');
    expect(result.first['id'], 'private');
    expect(result[6]['id'], 'owner-ad');
    expect(result[13]['id'], 'other-ad');
    expect(result.map((r) => r['id']).toSet().length, result.length);
  });
}
