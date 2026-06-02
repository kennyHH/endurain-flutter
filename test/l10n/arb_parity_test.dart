import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards translation completeness so new strings cannot ship in only one
/// locale. Compares the message keys (ignoring `@`-prefixed metadata) between
/// the English and Portuguese ARB catalogs.
void main() {
  group('ARB translation parity', () {
    late Map<String, dynamic> en;
    late Map<String, dynamic> pt;

    setUpAll(() {
      en = _loadArb('lib/l10n/app_en.arb');
      pt = _loadArb('lib/l10n/app_pt.arb');
    });

    test('every English key has a Portuguese translation', () {
      final missing = _messageKeys(en).difference(_messageKeys(pt));
      expect(
        missing,
        isEmpty,
        reason: 'Missing Portuguese translations for: ${missing.join(', ')}',
      );
    });

    test('Portuguese has no keys absent from English', () {
      final extra = _messageKeys(pt).difference(_messageKeys(en));
      expect(
        extra,
        isEmpty,
        reason: 'Portuguese defines unknown keys: ${extra.join(', ')}',
      );
    });

    test('placeholders match between locales', () {
      for (final key in _messageKeys(en)) {
        expect(
          _placeholders(en, key),
          _placeholders(pt, key),
          reason: 'Placeholder mismatch for "$key"',
        );
      }
    });

    test('no Portuguese translation is left empty', () {
      for (final key in _messageKeys(pt)) {
        expect(
          (pt[key] as String).trim(),
          isNotEmpty,
          reason: 'Empty Portuguese translation for "$key"',
        );
      }
    });
  });
}

Map<String, dynamic> _loadArb(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing ARB file: $path');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Set<String> _messageKeys(Map<String, dynamic> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}

Set<String> _placeholders(Map<String, dynamic> arb, String key) {
  final metadata = arb['@$key'];
  if (metadata is! Map<String, dynamic>) {
    return <String>{};
  }
  final placeholders = metadata['placeholders'];
  if (placeholders is! Map<String, dynamic>) {
    return <String>{};
  }
  return placeholders.keys.toSet();
}
