/// Identity of the build, in one place.
///
/// Lives here rather than in `main.dart` so the About dialog and the audit session row can
/// both read it without importing the entry point. Kept in step with `pubspec.yaml`'s
/// `version:` by `app_info_test.dart` — a version that disagrees with the package is a
/// version that means nothing in a bug report.
library;

const String appName = 'World Keeper';

const String appVersion = '1.0.0';

/// One line, for the About dialog header.
const String appTagline =
    'Manages a Core Keeper dedicated server’s worlds over SSH.';
