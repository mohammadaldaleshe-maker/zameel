/// Quiz progression is based on correct answers, never attempted questions.
class QuizProgress {
  const QuizProgress(this.correct);
  final int correct;
  static const starts = [0, 16, 31, 81, 141, 351];
  static const arabicNames = ['تمهيدي', 'سهل', 'متوسط', 'صعب', 'متقدم', 'خبير'];
  static const englishNames = ['Beginner', 'Easy', 'Medium', 'Hard', 'Advanced', 'Expert'];
  int get level {
    for (var i = starts.length - 1; i >= 0; i--) {
      if (correct >= starts[i]) return i + 1;
    }
    return 1;
  }
  int get earnedInLevel => correct - starts[level - 1];
  int? get requiredInLevel => level == 6 ? null : starts[level] - starts[level - 1];
  String label(bool arabic) => (arabic ? arabicNames : englishNames)[level - 1];
}
