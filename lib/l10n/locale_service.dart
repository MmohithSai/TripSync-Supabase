import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static const String _localeKey = 'selected_locale';
  
  static const List<Locale> supportedLocales = [
    Locale('en', ''), // English
    Locale('ml', ''), // Malayalam
    Locale('hi', ''), // Hindi
  ];

  static Locale getSystemLocale() {
    final systemLocale = PlatformDispatcher.instance.locale;
    // Check if system locale is supported
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == systemLocale.languageCode) {
        return supportedLocale;
      }
    }
    // Default to English if system locale is not supported
    return supportedLocales.first;
  }

  static Future<Locale> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_localeKey);
    
    if (localeCode != null) {
      for (final locale in supportedLocales) {
        if (locale.languageCode == localeCode) {
          return locale;
        }
      }
    }
    
    return getSystemLocale();
  }

  static Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  static String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'ml':
        return 'മലയാളം';
      case 'hi':
        return 'हिन्दी';
      default:
        return 'English';
    }
  }
}








