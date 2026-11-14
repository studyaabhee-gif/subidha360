import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/language.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

import 'core/l10n/tr.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    return MaterialApp.router(
      // A new key rebuilds every screen in the chosen language.
      key: ValueKey(language),
      title: tr('Subidha360'),
      // Flutter marks development builds with a DEBUG ribbon. Release builds
      // never show it; hiding it here keeps test screenshots clean too.
      debugShowCheckedModeBanner: false,
      locale: Locale(language.code),
      supportedLocales: const [Locale('en'), Locale('ne')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
