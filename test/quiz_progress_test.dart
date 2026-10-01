import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/services/quiz_progress.dart';
void main() {
  test('every approved progression boundary is based on correct answers', () {
    const expected = {0:1,15:1,16:2,30:2,31:3,80:3,81:4,140:4,141:5,350:5,351:6};
    for (final entry in expected.entries) {
      expect(QuizProgress(entry.key).level, entry.value);
    }
    expect(QuizProgress(16).earnedInLevel, 0);
    expect(QuizProgress(31).requiredInLevel, 50);
    expect(QuizProgress(141).requiredInLevel, 210);
    expect(QuizProgress(351).requiredInLevel, isNull);
  });
}
