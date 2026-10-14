// Calendar dates are compared without converting a birthday to a timezone instant.
String? birthdayError158(DateTime? birth,
    {required bool student, DateTime? now}) {
  if (birth == null) return 'أدخل تاريخ ميلادك';
  final today = now ?? DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  if (birth.isBefore(DateTime(1960)) || birth.isAfter(day))
    return 'أدخل تاريخ ميلاد صحيحًا من عام 1960 وحتى اليوم';
  final seventeenth = DateTime(birth.year + 17, birth.month, birth.day);
  if (student && seventeenth.isAfter(day))
    return 'يجب أن يكون عمر الطالب الجامعي 17 عامًا مكتملة على الأقل';
  return null;
}
