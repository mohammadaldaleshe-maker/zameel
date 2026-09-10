import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('ar', '');

  Locale get currentLocale => _currentLocale;

  bool get isArabic => _currentLocale.languageCode == 'ar';

  String get currentLanguage => _currentLocale.languageCode;

  void changeLanguage(String languageCode) {
    if (_currentLocale.languageCode == languageCode) return;
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }

  // ✅ دالة تبديل اللغة (جديدة)
  void toggleLanguage() {
    if (_currentLocale.languageCode == 'ar') {
      changeLanguage('en');
    } else {
      changeLanguage('ar');
    }
  }
}