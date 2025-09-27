import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'locale_service.dart';
import 'app_localizations.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(LocaleService.supportedLocales.first) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final locale = await LocaleService.getSavedLocale();
    state = locale;
  }

  Future<void> setLocale(Locale locale) async {
    await LocaleService.saveLocale(locale);
    state = locale;
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final locale = ref.watch(localeProvider);
  return lookupAppLocalizations(locale);
});


