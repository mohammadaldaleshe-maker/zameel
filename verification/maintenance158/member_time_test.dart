import 'package:zameel/services/member_rules158.dart';
import 'package:zameel/services/post_presentation157.dart';

void main() {
  final now = DateTime.utc(2026, 10, 14, 12);
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  for (final item in <List<Object>>[
    [0, 'الآن'],
    [59, 'الآن'],
    [60, 'قبل دقيقة'],
    [120, 'قبل دقيقتين'],
    [300, 'قبل 5 دقائق'],
    [3600, 'قبل ساعة'],
    [86400, 'قبل يوم'],
    [432000, 'قبل 5 أيام']
  ]) {
    check(
        relativePostTime158(
                now
                    .subtract(Duration(seconds: item[0] as int))
                    .toIso8601String(),
                now: now) ==
            item[1],
        'relative ${item[0]}');
  }
  check(relativePostTime158('bad').isEmpty, 'malformed');
  check(relativePostTime158(null).isEmpty, 'null');
  check(birthdayError158(null, student: false, now: now) != null, 'required');
  check(
      birthdayError158(DateTime(1959, 12, 31), student: false, now: now) !=
          null,
      '1960 lower');
  check(birthdayError158(DateTime(1960), student: false, now: now) == null,
      '1960 allowed');
  check(
      birthdayError158(DateTime(2026, 10, 15), student: false, now: now) !=
          null,
      'future');
  check(
      birthdayError158(DateTime(2009, 10, 14), student: true, now: now) == null,
      '17 today');
  check(
      birthdayError158(DateTime(2009, 10, 15), student: true, now: now) != null,
      'not yet17');
  print(
      'PASS: relative Arabic time boundaries and calendar birthday/17-year rules.');
}
