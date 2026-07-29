import 'package:flutter/widgets.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// The string table, without a widget tree.
///
/// `lookupAppLocalizations` is what the delegate itself calls, so this is the same object
/// a running app gets — not a stub that could drift from it.
///
/// English by default: tests assert on copy, and asserting against the *source* language
/// is the only way for a wrong translation to be a translation bug rather than a test
/// failure everywhere.
AppLocalizations l10nFor([String languageCode = 'en']) =>
    lookupAppLocalizations(Locale(languageCode));
