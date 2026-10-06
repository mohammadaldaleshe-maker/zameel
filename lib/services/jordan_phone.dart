/// Validates the submitted number before converting it; letters are never removed.
String? normalizeJordanMobile(String input) {
  var value = input.trim().replaceAll(RegExp(r'[\s-]'), '');
  if (RegExp(r'^07[789]\d{7}$').hasMatch(value)) {
    return '+962${value.substring(1)}';
  }
  if (RegExp(r'^009627[789]\d{7}$').hasMatch(value)) {
    value = '+962${value.substring(5)}';
  }
  return RegExp(r'^\+9627[789]\d{7}$').hasMatch(value) ? value : null;
}
