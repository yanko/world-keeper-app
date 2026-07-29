import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// The ARB files, checked against each other.
///
/// A missing translation does not fail a build and does not throw at runtime — gen_l10n
/// silently falls back to English, so the French user gets an English sentence with
/// nothing to indicate anything is wrong. Nor does a *dropped placeholder*: `"Monde
/// restauré"` compiles and runs perfectly, and simply never says which world.
///
/// Everything here is about that class of failure: the ones that look fine.
void main() {
  final root = Directory.current;

  Map<String, dynamic> arb(String locale) =>
      jsonDecode(
            File('${root.path}/lib/l10n/app_$locale.arb').readAsStringSync(),
          )
          as Map<String, dynamic>;

  /// Message keys only — `@@locale` and the `@key` metadata entries are not messages.
  Set<String> messageKeys(Map<String, dynamic> table) =>
      table.keys.where((k) => !k.startsWith('@')).toSet();

  /// The `{name}` substitutions a message takes.
  ///
  /// Must start with a letter: ICU plurals write their branches as `=1{1 step}`, and a
  /// looser pattern reads the `1` there as a placeholder called "1".
  Set<String> placeholdersIn(String message) => RegExp(r'\{([a-zA-Z]\w*)')
      .allMatches(message)
      .map((m) => m.group(1)!)
      .where((name) => name != 'plural' && name != 'other')
      .toSet();

  late Map<String, dynamic> en;
  late Map<String, dynamic> fr;

  setUpAll(() {
    en = arb('en');
    fr = arb('fr');
  });

  test('every supported locale has an ARB file', () {
    for (final locale in supportedLocales) {
      expect(
        File(
          '${root.path}/lib/l10n/app_${locale.languageCode}.arb',
        ).existsSync(),
        isTrue,
        reason: '${locale.languageCode} is offered but has no strings',
      );
    }
  });

  test('French translates every English message and adds none of its own', () {
    final english = messageKeys(en);
    final french = messageKeys(fr);

    expect(
      english.difference(french),
      isEmpty,
      reason: 'untranslated — these would silently appear in English',
    );
    expect(
      french.difference(english),
      isEmpty,
      reason: 'orphaned — no code path can reach these',
    );
  });

  test('placeholders survive translation', () {
    // The failure this catches is a sentence that reads perfectly and has lost its
    // subject: "Monde restauré." where the English said "Restored world 3".
    for (final key in messageKeys(en)) {
      expect(
        placeholdersIn(fr[key] as String),
        placeholdersIn(en[key] as String),
        reason: '$key has different placeholders in French',
      );
    }
  });

  test('no full sentence was left in English', () {
    // Short strings legitimately coincide — "Terminal", "Port", "OK", "Docker" are the
    // same word in both. A long one that is byte-identical is a paste that never got
    // translated, so the length threshold is the whole test.
    const sentenceLength = 45;

    final untranslated = [
      for (final key in messageKeys(en))
        if ((en[key] as String).length >= sentenceLength && en[key] == fr[key])
          key,
    ];

    expect(untranslated, isEmpty, reason: 'still English in app_fr.arb');
  });

  test('the source language documents its own placeholders', () {
    // gen_l10n needs the `@key.placeholders` metadata to give a parameter a type; without
    // it every substitution becomes `Object` and the call sites lose their type checking.
    for (final key in messageKeys(en)) {
      final placeholders = placeholdersIn(en[key] as String);
      if (placeholders.isEmpty) continue;

      final meta = en['@$key'] as Map<String, dynamic>?;
      expect(
        meta,
        isNotNull,
        reason: '$key takes placeholders but has no @$key entry',
      );
      expect(
        (meta!['placeholders'] as Map<String, dynamic>?)?.keys.toSet(),
        placeholders,
        reason: '$key documents different placeholders than it uses',
      );
    }
  });

  test('every language the picker offers can say its own name', () {
    // The one list in an app that must not be in the app's current language: someone who
    // has cycled one step too far and cannot read the interface is looking for the word
    // they recognise.
    for (final locale in supportedLocales) {
      expect(
        localeNativeNames[locale.languageCode],
        isNotNull,
        reason: 'no endonym for ${locale.languageCode}',
      );
    }
  });
}
