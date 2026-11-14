import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subidha360/core/l10n/language.dart';
import 'package:subidha360/core/l10n/nepali.dart';
import 'package:subidha360/core/l10n/nepali_catalog.dart';
import 'package:subidha360/core/l10n/tr.dart';
import 'package:subidha360/core/providers/core_providers.dart';
import 'package:subidha360/features/catalog/domain/catalog.dart';
import 'package:subidha360/features/jobs/domain/job.dart';

/// Text that is the same in both languages.
const _sameInBoth = {
  '{0}Rs {1}.{2}',
  'Rs  ',
  'Rs 500',
  'Rs 650',
  'Rs 800',
  'Subidha',
  'Subidha360',
  '© OpenStreetMap',
};

/// Reads the English keys out of every tr('...') call in the app.
Set<String> sourceKeys() {
  final call = RegExp(
    r"""\btr\(\s*((?:(?:'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")\s*)+)""",
  );
  final piece = RegExp(
    r"""\x27((?:[^'\\]|\\.)*)\x27|\x22((?:[^"\\]|\\.)*)\x22""",
  );
  final keys = <String>{};
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    if (file.path.contains('l10n')) continue;
    for (final match in call.allMatches(file.readAsStringSync())) {
      final text = piece
          .allMatches(match[1]!)
          .map((p) => p[1] ?? p[2]!)
          .join()
          .replaceAll(r"\'", "'")
          .replaceAll(r'\"', '"')
          .replaceAll(r'\$', r'$');
      keys.add(text);
    }
  }
  return keys;
}

Set<String> placeholders(String text) =>
    RegExp(r'\{\d+\}').allMatches(text).map((m) => m[0]!).toSet();

void main() {
  tearDown(() => appLanguage = AppLanguage.english);

  test('every string in the app has a Nepali translation', () {
    final keys = sourceKeys();
    expect(keys.length, greaterThan(300));
    final missing = keys
        .difference(_sameInBoth)
        .where((k) => !nepaliText.containsKey(k))
        .where((k) => !nepaliCatalog.containsKey(k));
    expect(missing, isEmpty);
  });

  test('translations keep every placeholder', () {
    for (final entry in {...nepaliText, ...nepaliCatalog}.entries) {
      expect(
        placeholders(entry.value),
        placeholders(entry.key),
        reason: entry.key,
      );
    }
  });

  test('every status and time window is translated', () {
    appLanguage = AppLanguage.nepali;
    for (final status in JobStatus.values) {
      expect(status.label, matches(RegExp('[ऀ-ॿ]')), reason: '$status');
    }
    for (final slot in timeSlots.values) {
      expect(nepaliText.containsKey(slot), isTrue, reason: slot);
    }
  });

  test('English stays English, and gaps fall back to English', () {
    expect(tr('Post a job'), 'Post a job');
    appLanguage = AppLanguage.nepali;
    expect(tr('Post a job'), 'काम पोस्ट गर्नुहोस्');
    expect(tr('Not translated yet'), 'Not translated yet');
  });

  test('values fill their placeholders in either language', () {
    expect(tr('Asking {0}', ['Ram']), 'Asking Ram');
    appLanguage = AppLanguage.nepali;
    expect(tr('Asking {0}', ['Ram']), 'Ram लाई सोधिँदै');
  });

  test('the chosen language is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer open() => ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    final first = open();
    addTearDown(first.dispose);
    expect(first.read(languageProvider), AppLanguage.english);
    await first.read(languageProvider.notifier).toggle();
    expect(appLanguage, AppLanguage.nepali);

    appLanguage = AppLanguage.english;
    final second = open();
    addTearDown(second.dispose);
    expect(second.read(languageProvider), AppLanguage.nepali);
    expect(appLanguage, AppLanguage.nepali);
  });

  test('people can search in Nepali', () {
    appLanguage = AppLanguage.nepali;
    const tap = CatalogService(
      id: 'tap-leak',
      name: 'Leaking tap repair',
      summary: 'Stop a dripping or loose tap, mixer or shower head.',
      categoryId: 1,
      guideFromPaisa: 0,
      guideToPaisa: 0,
      symptoms: ['tap dripping'],
    );
    const catalog = [
      CatalogCategory(
        id: 1,
        slug: 'plumbing',
        name: 'Plumbing',
        tagline: '',
        services: [tap],
      ),
    ];
    expect(catalog.search('धारा'), [tap]);
    expect(catalog.search('tap'), [tap]);
    expect(catalog.search('ल्यापटप'), isEmpty);
  });
}
