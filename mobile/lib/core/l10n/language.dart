import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/context_extensions.dart';
import '../providers/core_providers.dart';
import 'tr.dart';

const _key = 'language';

/// The chosen language, remembered on this device.
class LanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    final language = AppLanguage.values.firstWhere(
      (value) => value.code == saved,
      orElse: () => AppLanguage.english,
    );
    appLanguage = language;
    return language;
  }

  Future<void> choose(AppLanguage language) async {
    appLanguage = language;
    state = language;
    await ref.read(sharedPreferencesProvider).setString(_key, language.code);
  }

  Future<void> toggle() => choose(
    state == AppLanguage.english ? AppLanguage.nepali : AppLanguage.english,
  );
}

final languageProvider = NotifierProvider<LanguageController, AppLanguage>(
  LanguageController.new,
);

/// Offers the other language, written in that language so anyone can find it.
class LanguageSwitch extends ConsumerWidget {
  const LanguageSwitch({this.compact = false, super.key});

  /// Shows only an icon, for tight headers.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    final other = current == AppLanguage.english
        ? AppLanguage.nepali
        : AppLanguage.english;
    void toggle() => ref.read(languageProvider.notifier).toggle();
    if (compact) {
      return IconButton(
        tooltip: other.label,
        onPressed: toggle,
        icon: const Icon(Icons.translate_rounded),
      );
    }
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: context.colors.onSurface),
      onPressed: toggle,
      icon: const Icon(Icons.translate_rounded, size: 18),
      label: Text(other.label, style: context.text.titleSmall),
    );
  }
}
