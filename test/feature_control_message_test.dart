import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zameel/services/feature_control.dart';

void main() {
  test('feature guards show one message without database details', () {
    for (final key in <String>[
      'radio', 'college_challenge', 'lamma', 'stories', 'clips',
      'polls', 'groups', 'posts', 'comments',
    ]) {
      final error = PostgrestException(message: '${key}_temporarily_unavailable');
      expect(FeatureControl.errorMessage(error, 'تعذر إكمال العملية'),
          'هذه الميزة معلقة حالياً');
    }
  });

  test('other errors retain their existing explanation', () {
    expect(FeatureControl.errorMessage(StateError('offline'), 'تعذر النشر'),
        contains('تعذر النشر'));
  });
}
