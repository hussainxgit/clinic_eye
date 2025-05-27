import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';

// 1. Define the StateNotifier for locale
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(AppLocalizations.supportedLocales.last); // Default to English
  void setLocale(Locale newLocale) {
    if (AppLocalizations.supportedLocales.contains(newLocale)) {
      state = newLocale;
    }
  }
}

// 2. Create a provider for the LocaleNotifier
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);
// 3. Create a function to get the current locale
Locale getCurrentLocale(WidgetRef ref) {
  return ref.watch(localeProvider);
}
// 4. Create a function to set the locale
void setLocale(WidgetRef ref, Locale locale) {
  ref.read(localeProvider.notifier).setLocale(locale);
}

// 5. Create a function to get the supported locales
List<Locale> getSupportedLocales() {
  return AppLocalizations.supportedLocales;
}

