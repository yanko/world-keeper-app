/// Access to the string table, and the set of languages it exists in.
///
/// ## What is translated, and what deliberately is not
///
/// The **interface** is: every label, button, heading, empty state, confirmation and
/// tooltip a person reads while deciding what to do.
///
/// The **record** is not. Audit event kinds (`push_start`, `service_stop`), the SSH
/// commands in the command reference, remote stderr, and the diagnostic text attached to
/// a failure all stay in English regardless of the interface language. Three reasons, in
/// order of how much they cost to get wrong:
///
/// 1. The audit log is evidence. It is exported to CSV and read by someone who was not
///    there — often on another machine, in another language. A log whose rows change
///    wording depending on who ran the app is not a log you can compare against another
///    one.
/// 2. Those strings are already written to SQLite by earlier sessions. Translating them
///    at write time would make the history bilingual; translating at read time would mean
///    a lookup table keyed on strings that were never meant to be keys.
/// 3. `sudo systemctl stop` does not have a French form, and a stderr line is the remote
///    machine talking, not us.
///
/// The dividing line is whether the string describes *the app* or *the server*. Anything
/// that comes back over the wire, or goes into the audit database, is the server's.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:world_keeper/l10n/app_localizations.dart';

export 'package:world_keeper/l10n/app_localizations.dart';

/// The string table for this [BuildContext].
///
/// `context.l10n.pushTitle` rather than `AppLocalizations.of(context).pushTitle`, because
/// the latter appears several hundred times and reads worse every time.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The languages the app ships, in the order the picker offers them.
///
/// English first because it is the source language — the ARB every other file is
/// generated against, and the one a missing translation falls back to.
const List<Locale> supportedLocales = [Locale('en'), Locale('fr')];

/// What a language calls itself.
///
/// A language list is the one list in an app that must not be in the app's current
/// language: someone who has accidentally set it to a language they cannot read needs to
/// find their way out, and "Anglais" does not help them. Endonyms are what they will be
/// looking for.
const Map<String, String> localeNativeNames = {
  'en': 'English',
  'fr': 'Français',
};

/// The delegates every localised widget needs.
///
/// [AppLocalizations.delegate] is ours; the three `GlobalX` ones are Material's, Cupertino's
/// and the framework's own — without them a French user gets French labels inside an
/// English date picker, and `TextField`'s cut/copy/paste menu stays in English too.
const List<LocalizationsDelegate<Object>> localizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
