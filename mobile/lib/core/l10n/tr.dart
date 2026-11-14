import 'nepali.dart';
import 'nepali_catalog.dart';

/// The languages the app speaks. English is the source text.
enum AppLanguage {
  english('en', 'English'),
  nepali('ne', 'नेपाली');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;
}

/// The current language. The whole app rebuilds when this changes.
AppLanguage appLanguage = AppLanguage.english;

/// Translates English text. Text without a translation stays in English, so a
/// gap shows English rather than nothing. {0}, {1}... are filled from [args].
String tr(String english, [List<Object?> args = const []]) {
  var text = appLanguage == AppLanguage.nepali
      ? (nepaliText[english] ?? nepaliCatalog[english] ?? english)
      : english;
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', '${args[i]}');
  }
  return text;
}
