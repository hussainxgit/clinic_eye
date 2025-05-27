import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/dashboard/view/dashboard_screen.dart';
import '../../config/app_theme.dart';
import '../../config/dependencies.dart';
import '../../locale/l10n/app_localizations.dart';
import '../../locale/locale_provider.dart'; // Import the locale provider

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider); // Watch the locale provider

    return MaterialApp(
      locale: currentLocale, // Use the locale from the provider
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        // Fallback to English if the device locale is not supported
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first; // Default to English
      },
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (BuildContext context) {
        return AppLocalizations.of(context)!.appName;
      },
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: DashboardScreen(
        toggleTheme: () {
          ref.read(themeModeProvider.notifier).state = !isDarkMode;
        },
        isDarkMode: isDarkMode,
      ),
    );
  }
}
