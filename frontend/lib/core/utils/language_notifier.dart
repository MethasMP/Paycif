import 'package:flutter/material.dart';

final languageNotifier = ValueNotifier<Locale>(const Locale('en'));

class LanguageNotifier {
  static final supportedLocales = [
    const Locale('en'),
    const Locale('zh'),
    const Locale('ja'),
    const Locale('ko'),
  ];

  static String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        return '中文 (Chinese)';
      case 'ja':
        return '日本語 (Japanese)';
      case 'ko':
        return '한국어 (Korean)';
      case 'en':
      default:
        return 'English';
    }
  }
}
