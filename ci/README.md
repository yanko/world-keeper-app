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

## `release.yml` — on a `v*` tag, or run by hand

| Job | Runner | Output |
|---|---|---|
| `version` | ubuntu | reads `pubspec.yaml`; on a tag, fails unless the tag is `v` + that version |
| `windows` | windows-2025-vs2026 | `WorldKeeper-X.Y.Z-windows-x64-setup.exe` (Inno Setup) |
| `macos` | macos-26 | `WorldKeeper-X.Y.Z-macos-universal.dmg` |
| `linux` | ubuntu | `WorldKeeper-X.Y.Z-linux-x64.tar.gz` |
| `android` | ubuntu | `WorldKeeper-X.Y.Z-android.apk`, release-signed, **only when the signing secrets exist** |
| `release` | ubuntu | tag pushes only: a **draft** release, "World Keeper vX.Y.Z", with everything attached |

**Test it without releasing:** Actions → `release` → *Run workflow*. A manual run builds
every platform and leaves the files under the run's *Artifacts* for 14 days. It never
creates a release.

**Draft on purpose.** Nothing is published until somebody has downloaded the installers
and run them once. Publish from the Releases page when you are happy.

None of the desktop builds is signed with a paid certificate. Windows shows SmartScreen and
macOS shows Gatekeeper on first launch; no amount of configuration substitutes for a
certificate.

### Android release signing

Android will only install an update over an app signed with the **same key**. That is why
the workflow never falls back to a debug key: each CI runner generates its own random
one, so no later build could ever be installed over a debug-signed APK. Users would have
to uninstall first and lose their profiles and audit log. Until the secrets below exist,
the `android` job skips itself with a warning and everything else still releases.

How it works: you make a **keystore** (a password-protected file holding your private
signing key) once, on your own machine. GitHub keeps a base64 copy of it and its
passwords as encrypted repository secrets. The workflow decodes the copy onto the runner,
signs the APK with it and deletes it. The secrets are never shown in logs, and forks
cannot read them.

1. **Create the keystore** (`keytool` comes with any JDK; Android Studio bundles one).
   Choose a strong password when it asks. Store the file **outside** the repository:

   ```
   keytool -genkey -v -keystore world-keeper-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias world-keeper
   ```

2. **Back it up** somewhere you will still have in five years, such as a password manager.
   If the keystore or its password is lost, no update can ever be installed over the
   existing app. There is no recovery.

3. **Encode it as base64** so it fits in a text secret:

   ```
   # PowerShell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("world-keeper-release.jks")) | Set-Clipboard
   # macOS / Linux
   base64 -w0 world-keeper-release.jks      # macOS: base64 -i world-keeper-release.jks
   ```

4. **Add four repository secrets** under GitHub → *Settings* → *Secrets and variables* →
   *Actions* → *New repository secret*:

   | Secret | Value |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | the base64 text from step 3 |
   | `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
   | `ANDROID_KEY_PASSWORD` | the key password (the same one, unless you set a different one) |
   | `ANDROID_KEY_ALIAS` | `world-keeper` |

5. Run the `release` workflow by hand and check that the `android` artifact appears.

To build a signed APK locally, copy `android/key.properties.example` to
`android/key.properties` (gitignored) and fill it in. `-PrequireReleaseSigning` makes
Gradle **fail** rather than fall back to the debug key, and the release workflow always
passes it.
