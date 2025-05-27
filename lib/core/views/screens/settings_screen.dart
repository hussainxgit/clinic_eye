import 'package:clinic_eye/core/locale/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../locale/locale_provider.dart'; // Import the locale provider

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(
      localeProvider,
    ); // Watch the locale provider

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.language),
              title: Text(AppLocalizations.of(context)!.language),
              subtitle: Text(
                currentLocale.languageCode == 'en' ? 'English' : 'العربية',
              ), // You can make this dynamic
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(AppLocalizations.of(context)!.language),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text('English'),
                          onTap: () {
                            Navigator.pop(context);
                            // Add language change logic here
                            ref
                                .read(localeProvider.notifier)
                                .setLocale(Locale('en'));
                          },
                        ),
                        ListTile(
                          title: Text('العربية'),
                          onTap: () {
                            Navigator.pop(context);
                            // Add language change logic here
                            ref
                                .read(localeProvider.notifier)
                                .setLocale(Locale('ar'));
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Add more settings options here
          ],
        ),
      ),
    );
  }
}
