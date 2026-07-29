# 02 — Target Architecture

## The one decision everything else follows from

**Reimplement the backend in pure Dart. Do not keep the Rust core behind FFI.**

The alternative — wrapping the existing `src-tauri` modules with `flutter_rust_bridge` —
is superficially attractive (the Rust is good, tested, and already correct). It is the
wrong call here, for one reason that dominates: **the brief says mobile**. Keeping Rust
means shipping a cross-compiled `russh` + `sqlx` + `keyring` toolchain for
android-arm64/armv7/x86_64 *and* ios-arm64/simulator, wiring NDK and Xcode toolchains
into CI, and debugging across an FFI boundary — on a codebase whose Rust exists mostly
to be a *backend for a webview*, a constraint Flutter removes entirely.

Everything the Rust does has a mature pure-Dart equivalent (verified — see
[03-DEPENDENCIES.md](03-DEPENDENCIES.md)), and `dartssh2` in particular is actively
maintained and offloads key exchange to background isolates. The one genuine gap is
Ed25519 OpenSSH key *generation* (~120 lines, see
[04-TRICKY.md](04-TRICKY.md#1-ssh-key-generation)).

Net: one language, one debugger, one build per platform, no cross-compilation.

---

## Layering

Strict dependency direction, enforced by folder and by import lint. Nothing in `data/`
or `domain/` may import `package:flutter/material.dart`.

```
lib/
├── main.dart                     # bootstrap only
├── app/                          # MaterialApp, router, theme, l10n wiring
├── features/<feature>/           # feature-first vertical slices
│   ├── domain/                   #   entities + repository interfaces (pure Dart)
│   ├── data/                     #   implementations (SSH, drift, storage)
│   └── presentation/             #   widgets + Riverpod providers
└── core/                         # cross-cutting: ssh transport, target trait,
                                  # audit db, result types, formatting, design system
```

Why feature-first rather than layer-first: the current app already partitions cleanly
along feature lines (push / pull / restore / stats / terminal / audit / discovery /
profiles), and every one of those has its own domain rules. A layer-first tree
(`models/`, `services/`, `widgets/`) would scatter each feature across four folders.

### The seam, preserved

`ServerTarget` translates to a Dart abstract interface almost verbatim. This is the
single most valuable design decision in the existing codebase and must survive:

```dart
abstract interface class ServerTarget {
  Future<ExecOutput> exec(String cmd);
  Future<int> pushFile(File local, String remote, {void Function(int, int)? onProgress});
  Future<int> pullFile(String remote, File local, {void Function(int, int)? onProgress});
  Future<List<FileEntry>> stat(String dir, String glob);
  Future<String> logsTail(int lines);
  Future<ExecOutput> serviceControl(ServiceAction action);
  Future<RunState> status();
  Future<String?> activeSince();
  Future<List<String>> udpListening();
  Future<void> fixPerms(String path);
  String get worldsPath;
  ServiceKind get serviceKind;
}
```

`SshTarget implements ServerTarget` holds all systemd/Docker/process branching. The
push/pull/restore state machines take a `ServerTarget` and stay target-agnostic — which
also makes them **unit-testable against a `FakeTarget`**, something the Rust version
never got (there are no tests in the current codebase).

`ServiceKind` becomes a sealed class, giving exhaustive `switch` — strictly better than
the Rust enum + serde tagging, and the compiler now enforces that adding a fourth kind
updates every command site:

```dart
sealed class ServiceKind {
  const ServiceKind();
}
final class SystemdService extends ServiceKind { final String unit; ... }
final class DockerService  extends ServiceKind { final String container; ... }
final class ProcessService extends ServiceKind {
  final String stopCmd, startCmd; final String? logPath; ...
}
```

---

## Replacing Tauri's primitives

| Tauri concept | Flutter equivalent | Note |
|---|---|---|
| `invoke("cmd")` | direct Dart call | The IPC boundary disappears entirely |
| `app.emit("push-progress")` | `Stream<PushProgress>` | Typed, no serialisation |
| `tauri-plugin-store` | JSON file via `path_provider` | Same file, same shape — see below |
| `tauri-plugin-sql` / `sqlx` | `drift` | Adds typed rows **and migrations** |
| `keyring` crate | `flutter_secure_storage` | Same OS backends |
| `tauri-plugin-dialog` | `file_picker` | |
| `tauri-plugin-clipboard-manager` | `Clipboard` (built-in) | No plugin needed |
| `revealItemInDir` | `url_launcher` / platform channel | Desktop only |
| `Mutex<Option<Connection>>` | Riverpod `Notifier` + a `Lock` | See below |
| `spawn_blocking` | `compute()` / `Isolate.run` | For zip + hashing |
| `russh` | `dartssh2` | |
| `xterm.js` | `xterm` (xterm.dart) | Same author lineage |
| `react-i18next` + JSON | `flutter_localizations` + ARB | Compile-time-checked keys |

### Config: keep the file format identical

`tauri-plugin-store` writes plain JSON. Writing the *same shape* to the *same location*
means an existing user's profiles carry over with zero migration, and both apps can be
installed side by side during the transition. Worth the small effort.

- Windows: `%APPDATA%/com.civortech.worldkeeper/config.json`
- Serialise with `freezed` + `json_serializable`, matching the existing camelCase keys
  and `#[serde(skip_serializing_if = "Option::is_none")]` behaviour (`includeIfNull:
  false`).

### Concurrency: reproducing `operation_lock` exactly

The subtlety in the Rust is that reads (stats, log tail, terminal) must **not** contend
with a running push, but push/pull/restore/disconnect must exclude each other via
`try_lock` — failing fast rather than queueing.

```dart
class OperationLock {
  Completer<void>? _held;
  bool get isBusy => _held != null;

  /// Mirrors Rust's `try_lock` — fails immediately, never queues.
  T? tryRun<T>(T Function() body) { ... }
}
```

Held by a Riverpod `Notifier` that also exposes `activeOperation` to the UI, so the
backend lock and the UI's disabled-button state are **one source of truth** instead of
the two parallel mechanisms the current app has (`operation_lock` in Rust +
`OperationsProvider.activeOperation` in React, which can in principle disagree).

`dartssh2`'s `SSHClient` multiplexes channels over one connection exactly like `russh`,
so the "clone the target, don't hold the lock" pattern maps directly — in Dart it's just
holding a reference; no clone needed.

### Progress: streams instead of events

The current design emits global Tauri events and the frontend subscribes *before*
invoking, because events fired with no listener are lost. That fragility disappears:

```dart
Stream<PushProgress> runPush(LocalWorldCandidate candidate) async* {
  yield const PushProgress(PushState.uploading);
  ...
}
```

Backed by a broadcast `StreamController` in the operations notifier so the log survives
tab switches — the same problem `OperationsProvider` was created to solve, solved by
keeping state in a provider that outlives the widgets (Riverpod providers are not tied
to the widget tree, so this is free rather than a workaround).

---

## State management: Riverpod, without code generation

Riverpod is the right fit: this app is almost entirely async state with dependencies
between pieces (connection → target → stats/worlds/backups), which is exactly what
`AsyncNotifier` + `ref.watch` handles well, and it gives free auto-disposal of the 5 s
stats poll when nothing is watching it.

**No `riverpod_generator`** — verified to be unresolvable alongside `drift_dev`
(`riverpod_generator` needs `analyzer ^13`, `drift_dev` an older major). Given a forced
choice, drift's codegen is the more valuable of the two: it buys schema **migrations**
on a database that lives on users' machines and evolves, whereas Riverpod's codegen buys
only syntax sugar. Hand-written providers are fully idiomatic:

```dart
final connectionProvider =
    NotifierProvider<ConnectionNotifier, ConnectionState>(ConnectionNotifier.new);

final statsProvider = StreamProvider.autoDispose<ServerStats>((ref) async* {
  final target = ref.watch(targetProvider);
  ...
});
```

Revisit when the analyzer constraints converge.

Provider map:

| Provider | Type | Notes |
|---|---|---|
| `configProvider` | `AsyncNotifier<AppConfig>` | profiles CRUD, persists on write |
| `connectionProvider` | `Notifier<ConnectionState>` | sealed: Disconnected/Connecting/Raw/Target |
| `targetProvider` | `Provider<ServerTarget?>` | derived; null unless connected+confirmed |
| `operationsProvider` | `Notifier<OperationsState>` | the lock + push/pull/restore logs |
| `statsProvider` | `StreamProvider.autoDispose` | 5 s poll, stale-guarded |
| `logTailProvider` | `StreamProvider.autoDispose.family<String,int>` | 2 s poll, drawer only |
| `remoteWorldsProvider` / `backupsProvider` | `FutureProvider` | manual invalidate |
| `auditProvider` | `AsyncNotifier` family per filter | |
| `themeModeProvider` / `localeProvider` | `Notifier` | shared_preferences |

---

## Error handling

The Rust returns `Result<T, String>` across the IPC boundary, which flattens
`anyhow`'s error chain to a `{:#}` string. Without an IPC boundary we can do better:

```dart
sealed class WkException implements Exception {
  final String message;
  final Object? cause;
}
final class SshException extends WkException { ... }
final class DiscoveryException extends WkException { ... }
final class OperationException extends WkException {
  final String step;        // which envelope step died — currently only in prose
  final String? rollbackNote;
}
```

Keeping the failing step as a **field** rather than embedded in a message string means
the UI can render "Stopping failed" structurally, and the audit row gets a real column.

Per SPEC §17, raw remote output and audit content stay untranslated; only the framing is
localised.

---

## Testing

The current codebase has **zero tests**. The rewrite should not repeat that, and the
`ServerTarget` seam makes it cheap:

- `FakeTarget implements ServerTarget` with scripted responses → unit-test the entire
  push/pull/restore envelope including rollback, timeout, and the
  "restart-anyway-after-failed-download" path, with **no server and no SSH**.
- Pure-function tests for the parsers, which is where the real bug density is:
  `findGameId` (reverse scan, three markers, `GameID path:` exclusion),
  `parseWorldFilename`, `dedupeParentDirs`, `parseMeminfo`, `parseDf`, `specificityRank`,
  the `docker port` → host-port extraction, and `shq`.
- `drift` has an in-memory executor → audit query/filter tests.
- Golden tests for the stepper at desktop and mobile widths.

Target: every parser and the three envelopes covered before any UI polish.
