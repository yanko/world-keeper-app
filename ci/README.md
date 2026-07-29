# CI

Two GitHub Actions workflows, in `.github/workflows/`.

That path is what both **GitHub** and **Forgejo Actions** read. Forgejo also accepts
`.forgejo/workflows/`; this location works on either, which matters if the project ever
changes host.

They used to live here, unwired, because this project was a subdirectory of the Tauri
app's repository and that repository's root already had a `release.yml` building the Rust
build. Splitting into a repository of its own removed the conflict, so they moved to the
root and now run.

## `ci.yml` — every push and pull request

| Job | Runner | What it does |
|---|---|---|
| `analyze` | ubuntu | `flutter analyze`, `dart format --set-exit-if-changed`, and three generated-file staleness checks |
| `test` | windows | the full suite |
| `build-windows` | windows | app + installer, uploaded as an artifact |
| `build-android` | ubuntu | release APK (debug-signed — see below) |

**Tests run on Windows, not Linux.** The audit database is SQLite reached through a native
asset, and the suite has only ever been verified against the Windows build of it. Running
it somewhere the app is never shipped would be testing a configuration nobody uses.

**The staleness checks regenerate and diff.** Localisations, launcher icons and the
drift/freezed output are all committed, and stale output is not something a test can
detect — it is valid, it just describes the previous version of the source. Regenerating
and asserting the tree did not move is the only exact check, so that is what runs.

## `release.yml` — on a `v*` tag

Builds a signed APK and app bundle plus the Windows installer, and opens a **draft**
release with them attached. Draft on purpose: nothing is published until somebody has
downloaded the installer and run it once.

Android signing needs four repository secrets:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 world-keeper-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_KEY_ALIAS` | key alias |

The release build passes `-PrequireReleaseSigning`, which makes Gradle **fail** rather
than fall back to the debug key. That fallback is right for a developer on a fresh clone
and catastrophic for a published artifact: a debug-signed APK installs, runs and looks
entirely normal, and can never be updated, because Android refuses a properly-signed build
over it. Every user who installed one would have to uninstall — losing their profiles and
their audit log — to move across.

Neither artifact is code-signed on Windows. That needs a certificate; no amount of
configuration substitutes for one. Users get the SmartScreen prompt on first run, the same
as the Tauri build has always shown.
