/// Display names only. City identities sent to the server stay unchanged.
const promotionGovernorates = <String>[
  'العاصمة',
  'إربد',
  'البلقاء',
  'الكرك',
  'معان',
  'الزرقاء',
  'المفرق',
  'الطفيلة',
  'مادبا',
  'جرش',
  'عجلون',
  'العقبة',
];

String promotionLocationSearch(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll(RegExp('[ًٌٍَُِّْ]'), '');

String promotionGovernorateName(Object? value) {
  final raw =
      (value?.toString() ?? '').trim().replaceFirst(RegExp(r'^محافظة\s+'), '');
  final key = promotionLocationSearch(raw);
  for (final name in promotionGovernorates) {
    if (promotionLocationSearch(name) == key) return name;
  }
  return raw;
}

String promotionCityLabel(Map<String, dynamic> city, {required bool arabic}) {
  final name = city['name']?.toString() ?? '';
  final governorate = promotionGovernorateName(city['governorate']);
  if (governorate.isEmpty) return name;
  return '$name — ${arabic ? 'محافظة ' : ''}$governorate';
}
