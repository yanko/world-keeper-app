# 03 — Dependency Stack (verified, not assumed)

Every package below was actually resolved, analyzed and compiled on this machine before
being written down — see [`lib/main.dart`](../lib/main.dart), the smoke test that
references a real symbol from each one. `flutter analyze` is clean and
`flutter build windows --release` links successfully.

**Toolchain:** Flutter 3.44.8 (stable, 2026-07-23) • Dart 3.12.2 • Android SDK 36 •
VS Enterprise 2026 18.8.0.

---

## Runtime dependencies

| Package | Version | Replaces | Why this one |
|---|---|---|---|
| `dartssh2` | 2.22.4 | `russh` + `russh-sftp` | The only serious pure-Dart SSH client. Password/pubkey/interactive auth, full SFTPv3, PTY shell, channel multiplexing. **Actively maintained** — 2.22.4 published the day this was written. Offloads key exchange to background isolates, so the UI doesn't jank on connect. |
| `xterm` | 4.0.0 | `xterm.js` | Terminal emulator widget. Older release (2 y) but **150/160 pub points, tested against Dart 3.12.2, all 6 platforms, wasm-ready**, no outdated deps. Its own docs demo an SSH client built on `dartssh2`. |
| `drift` + `drift_flutter` | 2.34.3 / 0.3.1 | `sqlx` + `tauri-plugin-sql` | Typed SQLite with a real **migration** system — the thing the current `CREATE TABLE IF NOT EXISTS` schema conspicuously lacks. `drift_flutter`'s `driftDatabase()` handles native libs on all platforms. |
| `flutter_secure_storage` | 10.3.1 | `keyring` crate | Same OS backends: Windows Credential Manager, macOS/iOS Keychain, Android Keystore, Linux libsecret. |
| `file_picker` | 11.0.2 | `tauri-plugin-dialog` | `pickFiles` / `getDirectoryPath` / `saveFile` across all 6 platforms. **API changed in 11.x** — static methods, not `FilePicker.platform`. |
| `flutter_riverpod` | 3.4.1 | React context/state | See [02-ARCHITECTURE.md](02-ARCHITECTURE.md#state-management-riverpod-without-code-generation). |
| `archive` | 4.0.9 | `zip` crate | Pure-Dart zip read/write for world archives and audit export. |
| `crypto` | 3.0.7 | `sha2` crate | SHA-256 upload verification; supports **streaming** via `sha256.bind(stream)`, so unlike the Rust we never read a 5 MB world fully into memory to hash it. |
| `cryptography` | 2.9.0 | — | Ed25519 keygen for the key-auth helper (replaces shelling out to `ssh-keygen`). |
| `path_provider` | 2.1.6 | Tauri path API | App config/data/support dirs. **See the pin below.** |
| `shared_preferences` | 2.5.5 | `localStorage` | Theme mode, language mode, disclaimer flag. |
| `window_manager` | 0.5.2 | `tauri.conf.json` windows | Desktop window size + **minimum size** (the current app sets none). No-op on mobile. |
| `go_router` | 17.3.0 | — | Declarative routing for the responsive shell; deep-linkable tabs. |
| `url_launcher` | 6.3.2 | `tauri-plugin-opener` | Opening the repo link; "show in folder" needs a small platform-specific helper. |
| `csv` | 8.0.0 | `csv` crate | Audit CSV export. **API changed** — `CsvEncoder` (a `StreamTransformer`), not `ListToCsvConverter`; lets the export stream to disk. |
| `intl` | 0.20.3 | — | Date/number formatting alongside `flutter_localizations`. |
| `freezed_annotation` / `json_annotation` | 3.1.0 / 4.12.0 | `serde` derives | Immutable models, unions, JSON. |
| `collection` | 1.19.1 | — | `groupBy`, equality helpers. |

Clipboard needs **no** package — Flutter's built-in `Clipboard.setData` replaces
`tauri-plugin-clipboard-manager` (which the current app needed only because webviews
don't reliably grant clipboard access).

## Dev dependencies

`build_runner` 2.15.1 • `drift_dev` 2.34.0 • `freezed` 3.2.5 • `json_serializable`
6.14.0 • `flutter_lints` 6.0.0.

---

## Two real conflicts found while validating

### 1. `riverpod_generator` ⨯ `drift_dev` — unresolvable

```
riverpod_generator >=4.0.6 depends on analyzer ^13.0.0
drift_dev          depends on an older analyzer major
⇒ version solving failed
```

Also `riverpod_lint` + `custom_lint` cannot co-resolve with `flutter_riverpod` 3.4.1 +
`freezed_annotation` 3.1.0 (`analyzer_plugin` constraints).

**Resolution:** use Riverpod **without** code generation and drop `riverpod_lint` /
`custom_lint`. Drift's codegen earns its place (migrations on a user-resident database);
Riverpod's is syntax sugar. Hand-written providers are fully idiomatic. Revisit when the
analyzer majors converge.

### 2. `path_provider_android` ≥ 2.3.0 breaks the Android build

`path_provider_android` 2.3.0+ depends on `package:jni`, whose `android/build.gradle`
does this:

```groovy
def agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.tokenize('.')[0] as int
if (agpMajor < 9) { apply plugin: 'kotlin-android' }   // ← skipped on AGP 9
...
kotlin { compilerOptions { ... } }                      // ← but used unconditionally
```

Flutter 3.44's Android template generates **AGP 9.0.1**, so the Kotlin plugin is never
applied and Gradle dies with:

```
Could not find method kotlin() for arguments [...] on project ':jni'
```

This is an upstream bug in `jni` 1.0.1, not a misconfiguration. **Resolution:** pin via
`dependency_overrides: path_provider_android: 2.2.23` — the newest release predating the
`jni` dependency. Remove the override once `package:jni` ships an AGP 9 fix.

### 3. AGP 9 splits the plugin ecosystem in half — pin to AGP 8.x

Fixing (2) exposed the general form of the same problem. Flutter 3.44's Android template
generates **AGP 9.0.1**, where Kotlin compilation moved to AGP's "built-in Kotlin",
toggled by `android.builtInKotlin` (template default: `false`). Plugins disagree about
which world they live in:

| Plugin | Behaviour on AGP 9 | Needs |
|---|---|---|
| `file_picker` 11.0.2, `jni` 1.0.1 | `if (agpMajor < 9) { apply kotlin-android }` — assume AGP compiles their `.kt` for them | `builtInKotlin=true` |
| `flutter_plugin_android_lifecycle` 2.0.35 | applies `kotlin-android` unconditionally — AGP 9 rejects this when built-in Kotlin is on | `builtInKotlin=false` |

With `false`, `file_picker`'s Kotlin is silently never compiled and the build dies at
Java compile time with `cannot find symbol: class FilePickerPlugin`. With `true`,
`flutter_plugin_android_lifecycle` fails to evaluate. **No value satisfies both.**

**Resolution — verified working:**

```
android/settings.gradle.kts   com.android.application    8.11.1
                              org.jetbrains.kotlin.android 2.2.20
android/gradle/wrapper/…      gradle-8.14-all.zip
android/app/build.gradle.kts  re-add id("org.jetbrains.kotlin.android")
android/gradle.properties     android.builtInKotlin=false
```

On AGP 8.x every plugin applies `kotlin-android` itself and they all agree. These are
also Flutter 3.44's stated *minimum supported* versions, so the build is warning-free —
8.9.1/Gradle 8.12/Kotlin 2.1.20 also builds but warns that support is about to be
dropped. Revisit when the ecosystem finishes migrating to AGP 9.

> Worth internalising: none of these three appear until you actually build for Android.
> A plan written from package descriptions alone would have shipped all of them as
> surprises.

---

## Verified build status

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter build windows --release` | ✅ `world_keeper.exe` |
| `flutter build apk --debug` | ✅ `app-debug.apk`, no warnings |
| macOS / iOS / Linux | Not verified — no runner on this machine |

---

## Deliberately not used

| Considered | Verdict |
|---|---|
| `flutter_rust_bridge` + the existing Rust | Rejected — see [02-ARCHITECTURE.md](02-ARCHITECTURE.md). Mobile cross-compilation cost outweighs reuse. |
| `sqlite3_flutter_libs` | **Discontinued** (`0.6.0+eol`, "no longer does anything"). `package:sqlite3` 3.x bundles natives itself; `drift_flutter` is the supported path. Present only transitively. |
| `process_run` / `Process.run("ssh-keygen")` | Rejected for keygen — absent on mobile. Pure-Dart Ed25519 instead. |
| `sqflite` | `drift` gives typed queries + migrations for the same native layer. |
| `bloc` | Riverpod fits the async-dependency graph here with less ceremony. |
| `provider` | Superseded by Riverpod. |
| `fl_chart` | No charts in scope. |

---

## Fonts

The current app bundles Geist / Geist Mono / JetBrains Mono via fontsource. Flutter
should vendor the same TTFs under `assets/fonts/` and declare them in `pubspec.yaml`
(**not** `google_fonts`, which fetches at runtime — unacceptable for a tool that must
work on an isolated homelab LAN, and it would change the terminal's metrics).

- **Geist** → UI chrome
- **Geist Mono** → machine data (paths, sizes, game ids, log tails)
- **JetBrains Mono** → the terminal specifically (tall x-height, unambiguous `0/O`,
  `1/l/I`), matching today's deliberate choice.
