# World Keeper

Manages a Core Keeper dedicated server's worlds over SSH — push, pull, back up and
restore inside a safe stop/operate/restart/verify envelope. Desktop-first, responsive down
to phones.

A Flutter rewrite of the original **World Keeper**, a Tauri v2 (Rust) + React/TS desktop
app which lives in its own repository and is untouched by this one. The two are
deliberately **config-compatible**: both read the same `config.json` and the same audit
database location, so they can be installed side by side and switched between freely. See
[docs/02 — Architecture](docs/02-ARCHITECTURE.md) for why that constraint was kept.

## Status: feature-complete and shippable

Connect, discover, watch live stats, push / pull / restore worlds, open a real shell, and
read the audit trail — on desktop and on a phone, in English or French. Icons, installer,
CI, key auth and interrupted-operation recovery are in place.

Everything left is additive, and the largest piece is **teaching the app to explain
itself** — see [TODO.md](TODO.md) for what and how, and
[docs/06 — Build Order](docs/06-BUILD-ORDER.md) for what is already done and why.

```
flutter analyze                       No issues found
dart format --set-exit-if-changed .   clean
flutter test                          769 passing
flutter build windows --release       OK
flutter build apk --release           OK
installer\windows\build.ps1           WorldKeeper-1.0.0-windows-x64-setup.exe, 12.8 MB
```

### Building a release

```bash
# Windows: builds the app, stages the VC++ runtime beside it, compiles the installer
powershell -ExecutionPolicy Bypass -File installer\windows\build.ps1
```

```bash
# Android: needs android/key.properties — see android/key.properties.example.
# Without it the build refuses rather than quietly using the debug key.
flutter build apk --release -PrequireReleaseSigning
```

Launcher icons are generated from `assets/icon/icon.png` and committed; re-run
`dart run flutter_launcher_icons` after changing the art. CI regenerates and fails on any
diff, so stale output cannot ship.

### Languages

English and French, cycled from the toolbar beside the theme toggle and persisted. Adding
one means an `app_<code>.arb` and an entry in `supportedLocales` / `localeNativeNames`;
`test/l10n/arb_test.dart` then holds it to the same key set and placeholders as English.

The **audit log is deliberately not translated** — event kinds, SSH commands and remote
stderr stay as recorded, because that log is evidence and gets exported and read
elsewhere. See the note at the top of [lib/l10n/l10n.dart](lib/l10n/l10n.dart).

Every failure branch of the safe envelope is covered against a fake target — stop
timeout, service failing during start, checksum mismatch, download-fails-then-restart-
fails, backup failure, cross-target rejection, and rollback with and without a backup.
No server, no network, no risk.

**Verified end to end against the reference LXC**: a real pull, a real push back through
the full nine-state envelope (5 MB over SFTP, checksum-verified), and a deliberately
induced failure that rolled back and restarted with the world byte-identical to the safety
backup. The game id was unchanged throughout.

### Destructive live tests are triple-gated

`test/integration/live_destructive_test.dart` stops a real service and overwrites a real
world. It requires the `live` tag, a named profile, **and** `WK_LIVE_DESTRUCTIVE=1`:

```bash
WK_LIVE_PROFILE="lxc-core-keeper" WK_LIVE_DESTRUCTIVE=1 flutter test --tags live test/integration/live_destructive_test.dart
```

Verified against the reference LXC: discovery correctly identified Debian 13, both
`corekeeper` systemd units, and the worlds path; stats returned live status, uptime,
memory, disk, server clock, the loaded game id and the UDP listener.

Verified against the **real Rust install on this machine**, not just fixtures: its three
profiles round-trip byte-identically and all 4,473 audit rows import cleanly, with the
original files left untouched (`test/core/real_install_compat_test.dart`, skipped when no
install is present).

### Live server tests are opt-in

`test/integration/live_server_test.dart` connects to a real host. It is tagged `live` and
excluded by default in `dart_test.yaml`, and additionally requires a profile name in the
environment — so `flutter test` and CI can never reach a real server by accident.

```bash
# read-only: connect, exec, status, list world files, concurrent channels
WK_LIVE_PROFILE="lxc-core-keeper" flutter test --tags live test/integration/live_server_test.dart
```

Add `WK_LIVE_WRITE=1` to also round-trip a file through SFTP with a `sha256sum` check; it
writes only to a uniquely-named `/tmp` file and removes it afterwards.

- **[PLAN.md](PLAN.md)** — start here
- [docs/01 — Feature Inventory](docs/01-FEATURE-INVENTORY.md)
- [docs/02 — Architecture](docs/02-ARCHITECTURE.md)
- [docs/03 — Dependencies](docs/03-DEPENDENCIES.md)
- [docs/04 — Tricky Bits & Risks](docs/04-TRICKY.md)
- [docs/05 — Responsive UI](docs/05-RESPONSIVE-UI.md)
- [docs/06 — Build Order](docs/06-BUILD-ORDER.md)

## Layout

```
lib/
├── app/           theme (OKLCH tokens), breakpoints, providers, destinations
├── core/
│   ├── target/    ServerTarget + SshTransport interfaces, ServiceKind (sealed),
│   │              ExecOutput, FileEntry, RunState, and the output parsers
│   ├── config/    models, AppPaths (Tauri-compatible), ConfigRepository
│   ├── audit/     drift schema, migrations, legacy ckmanager.db importer, audit sink
│   ├── errors/    sealed WkException hierarchy
│   └── ssh/       SshSession (dartssh2), SshTarget (the command matrix),
│                  HostKeyStore (TOFU), key generation, shq() quoting, wire codec
└── features/
    ├── connection/  sealed ConnectionStatus, controller, bar, host-key dialog
    ├── discovery/   read-only probe + confirmation screen
    ├── stats/       StatsService, dashboard, live log
    ├── operations/  push / pull / restore envelopes, local world resolution,
    │                the fail-fast operation lock, interrupted-operation recovery
    ├── terminal/    PTY session, sticky modifiers, mobile accessory key bar
    ├── audit/       filtered and paged log views, zip export
    ├── about/       command reference, About and the safety notice
    └── shell/       responsive navigation shell

test/support/  FakeTransport + FakeTarget — no server, no network
```

Layout by width: bottom bar under 600 px, icon rail from 600, labelled rail from 1024,
and a permanent live-log pane from 1440.

`core/target`, `core/ssh`, `core/errors` and every future `features/*/domain` must stay
Flutter-free so the transport and the push/pull/restore envelopes can be tested
headlessly. That rule is enforced by `test/architecture_test.dart`, not by convention.

Flutter 3.44.8 · Dart 3.12.2. macOS / iOS / Linux are unverified — no runner on the
machine this was set up on.

## Android configuration — read before touching it

The Android build is pinned to **AGP 8.11.1 / Gradle 8.14 / Kotlin 2.2.20** instead of
the AGP 9.0.1 the Flutter 3.44 template generates, and `path_provider_android` is pinned
to 2.2.23. Both are deliberate workarounds for upstream plugins that are not yet AGP 9
ready — there is no `android.builtInKotlin` setting that satisfies all of them at once.

Details and the reasoning are in
[docs/03](docs/03-DEPENDENCIES.md#3-agp-9-splits-the-plugin-ecosystem-in-half--pin-to-agp-8x),
and inline in `android/gradle.properties`. Please don't "upgrade" these without
re-running an Android build.

## Commands

```bash
flutter pub get
flutter run -d windows
flutter run -d android
flutter analyze
```
