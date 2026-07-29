# 06 — Build Order

Sequenced so that each phase is independently demoable and the **risky, load-bearing
parts land early** — the same discipline as SPEC §13, which put the SSH transport and a
read-only discovery probe before anything destructive.

Two rules throughout:

- **Nothing destructive ships before its rollback path is tested.** Phase 5 writes to a
  real server; it must not land before Phase 4's fake-target tests exist.
- **All five platforms build on every commit** from Phase 0. Both Android breakages
  found while validating this stack ([03](03-DEPENDENCIES.md#two-real-conflicts-found-while-validating))
  were invisible until an actual build ran.

---

### Phase 0 — Foundation ✅ **done**

Scaffold, dependency stack resolved and pinned, `flutter analyze` clean, Windows release
build verified, Android AGP 9 issues diagnosed and worked around.
`analysis_options.yaml` hardened (`strict-casts`/`strict-raw-types`/`strict-inference`,
non-exhaustive switches and discarded futures promoted to **errors**), folder skeleton in
place, and an architecture test enforcing that `core/target`, `core/ssh`, `core/errors`
and every `features/*/domain` stay Flutter-free.

Remaining: CI matrix (Windows + Android now; macOS/iOS/Linux when a runner exists), and
vendoring the three fonts.

---

### Phase 1 — Core plumbing, no UI ✅ **done**

Everything below the feature layer. Ends with unit tests, not a screen.

- `lib/core/target/` — `ServiceKind` (**sealed**, hand-written JSON for exact serde
  parity), `ExecOutput`, `FileEntry`, `ServiceAction`, `RunState`.
- `lib/core/config/` — `Profile`, `Discovered`, `AppConfig`, `WorldDetection`,
  `AuthMethod` (freezed + json_serializable), `AppPaths` (**reproduces Tauri's** path
  resolution, not `path_provider`'s), `ConfigRepository` (atomic writes, preserves
  foreign store keys).
- ~~`lib/core/secrets/` — `SecretsRepository` over `flutter_secure_storage`.~~ Removed in
  9.2: never wired to anything, and key auth answers the same question better.
- `lib/core/audit/` — six drift tables, `schemaVersion: 1`, `MigrationStrategy` with
  foreign keys enforced, `truncateCapture`, and `LegacyAuditImporter` reading an existing
  `ckmanager.db` **read-only**.
- `lib/core/errors/` — sealed `WkException` hierarchy carrying the failing step as a
  field.
- `lib/core/ssh/` — `shq()` and the SSH-wire reader/writer that key generation needs.

**Exit — met, and verified against the real install on this machine:**

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **93 passing** |
| Real `config.json` round-trip | 3 real profiles (1 systemd + 2 Docker) re-serialise **byte-identically** |
| Real `ckmanager.db` import | **4,473 rows** (24 sessions, 193 events, 9 backups, 4,247 ssh_commands), ids and relationships preserved |
| Legacy files after import | size + mtime unchanged — the Rust app's history is untouched |

Two findings worth recording:

- **`explicit_to_json` was needed.** json_serializable's default leaves nested objects
  *as objects* in the map returned by `toJson()`, relying on `jsonEncode` to convert them
  later. That happens to produce correct output when the map goes straight to
  `jsonEncode` — and silently wrong output anywhere else. The byte-compatibility test
  caught it; fixed globally in `build.yaml`.
- **The store wrapper is real.** `tauri-plugin-store` nests everything under a `"config"`
  key, so the file is `{"config": {...}}`, not the config at the top level. Confirmed
  against the live file.

---

### Phase 2 — SSH transport + `ServerTarget` ✅ **done**

The load-bearing phase.

- `lib/core/target/server_target.dart` — the `ServerTarget` interface, plus `SshTransport`
  and `SshCommandAuditSink`. Splitting the transport out is what makes the command matrix
  assertable and keeps `core/ssh` free of drift.
- `lib/core/target/parsers.dart` — every remote-output parser as a pure function.
- `lib/core/ssh/ssh_session.dart` — `dartssh2` transport: password + key auth, audited
  `exec`, **streaming** SFTP with progress callbacks, PTY channel, `installPublicKey`.
- `lib/core/ssh/ssh_target.dart` — the full per-ServiceKind command matrix, the four-tier
  Docker `udpListening` fallback with its `success` guard, and `fixPerms`.
- `lib/core/ssh/host_key_store.dart` — TOFU pinning
  ([04 §8](04-TRICKY.md#-8-host-key-verification-existing-security-gap)).
- `lib/core/audit/audit_sink.dart` — binds the transport's audit interface to drift.
- `test/support/` — `FakeTransport` (records exact command strings) and `FakeTarget`
  (scriptable states/failures), ready for Phase 4.

**Exit — met:**

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **174 passing** |
| Command matrix | Every systemd/Docker/process command asserted literally |
| Docker `udpListening` | All four tiers covered, including the exec-error-on-stdout guard |
| Parsers | `findGameId` (reverse scan, 3 markers, `GameID path:` exclusion), `parseWorldFilename`, `parseFindPrintf` (spaces in paths), `parseMeminfo`, `parseDf`, `parseDockerUdpPorts` (IPv6 `[::]:port`), status normalisation |
| Live server | Opt-in integration test, **not run** — see below |

Three decisions worth recording:

- **`find -printf` fallback landed early.** It was planned for Phase 3's discovery probe,
  but `stat()` is Phase 2 and the failure mode is silent: a BusyBox host returns *no
  output*, which reads as "no worlds found" rather than as an error. `stat()` now probes
  by result — try `-printf`, fall back to `-exec stat -c`, cache whichever works. An empty
  *successful* listing deliberately does not trigger the fallback.
- **`restarting` maps to `unknown`, not `running`.** A crash-looping container reports
  `restarting`; treating that as up would let the envelope call a start successful moments
  before the next crash. The Rust version mapped it to `unknown` only by omission — here
  it is explicit and tested.
- **Host keys are pinned in their own file**, not on the profile, so `config.json` stays
  byte-compatible with the Rust app. That also mirrors how OpenSSH itself works.

**Live verification is opt-in.** `test/integration/live_server_test.dart` covers the rest
of the exit criteria — connect, exec, audit capture, `stat` against real world files,
concurrent channels, and an SFTP round trip with a `sha256sum` check. It is tagged `live`
and excluded by default via `dart_test.yaml`, and additionally requires a profile name in
the environment, so it can never reach a real server from a plain `flutter test` or CI run:

```bash
WK_LIVE_PROFILE="lxc-core-keeper" flutter test --tags live test/integration/live_server_test.dart
```

The default set is strictly read-only. The SFTP round trip is gated behind a second flag
(`WK_LIVE_WRITE=1`), writes only to a uniquely-named file under `/tmp`, and removes it
afterwards.

---

### Phase 3 — Shell, discovery, stats ✅ **done** *(first runnable app)*

Read-only. Safe against a live server.

- `lib/app/` — `WkColors` theme extension (OKLCH tokens converted at runtime rather than
  hand-transcribed to hex), `WindowSize` breakpoints, hand-written Riverpod providers,
  the destination list.
- `lib/features/connection/` — sealed `ConnectionStatus`, `ConnectionController`, the
  connection bar, profile dialog, and the host-key trust dialog.
- `lib/features/discovery/` — the read-only probe and its confirmation screen.
- `lib/features/stats/` — `StatsService`, the dashboard, and the live log panel.
- `lib/features/shell/` — the responsive shell.

**Exit — met:**

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **254 passing** (12 of them responsive-shell widget tests at 360/768/1100/1440 px) |
| `flutter build windows --release` | OK, launches, window responds |
| Live discovery | Correctly identified Debian 13, both `corekeeper` units, and the worlds path on the reference LXC |
| Live stats | status `active`, uptime, memory, disk, server clock, **game id `ckrN2fzdAw6MR7f`**, 1 UDP listener |

Deviations from the plan, all deliberate:

- **`StatefulShellRoute` was not used.** `go_router` earns its place when there is
  deep-linking or URL state to model; here the shell is six sibling destinations with no
  routes to address. A plain `IndexedStack` gives the same keep-alive guarantee — which
  is the load-bearing part, since the terminal will hold a live PTY — without the
  indirection. `go_router` stays a dependency for when nested routes actually appear.
- **`signalText` was added to the palette.** The badge teal reaches only ~2.3:1 on the
  light background, so using it for labels and icons would make exactly the information
  the palette exists to highlight the hardest to read. `signal` is now the fill and
  `signalText` the (darker, AA-passing) foreground, with a contrast test forcing them
  apart.
- **Discovery candidate filtering.** See below.

#### Two findings from the live probe

**The reference host is genuinely ambiguous**, exactly as the original design predicted:
`corekeeper` *and* `corekeeper-api` both match `grep -i core`. The probe refuses to guess
and ranks the real one first — behaviour ported faithfully and now covered by tests.

**Worlds-path discovery degrades badly on a used host.** Every push writes a dated copy
into `<worldsPath>/.backups/<slot>.<timestamp>/`, and those copies are `*.world.gzip`
files too — so `find /home -name '*.world.gzip'` returns one directory per backup ever
made. The reference host offered **sixteen** candidates, fifteen of them backups of the
one real answer. The Rust app has the identical behaviour; it simply doesn't appear until
the app has been used for a while.

`dedupeParentDirs` now drops anything inside a `.backups` or `.staging` segment (only
those two names — a blanket "skip hidden directories" rule would discard the real answer,
which lives under `~/.config`), collapses descendants into a containing candidate, and
orders what remains so a directory actually named `worlds` sorts first. Sixteen candidates
became two — the live worlds directory and a sibling `worlds.bak.2026-07-24` a human made,
which is a real question worth asking — with the right one pre-selected.

---

### Phase 4 — The envelopes, headless ✅ **done**

Write the state machines **and their tests** before any destructive UI exists.

- `lib/features/operations/data/envelope.dart` — `ServiceControl` (poll / timeout / early
  bail) and `WorldOperations` (backup, rollback, game-id capture, UDP wait, backup
  listing), plus injectable `EnvelopeTimings`.
- `push_envelope.dart` — the full safe swap: streaming SHA-256 verification, exact-pair
  backup, canonical upload rename, rollback.
- `pull_envelope.dart` — stop / download / restart, plus local packaging to folder or zip.
- `restore_envelope.dart` — the path-containment guard and the pre-restore safety backup.
- `local_world_resolver.dart` — folder / zip / single file, recursive scan, slot grouping,
  loose match.
- `operation_lock.dart` — fail-fast mutual exclusion across the three.

**Exit — met. 112 operations tests, 366 in total:**

| Branch | Covered |
|---|---|
| Timeout during stop | ✔ and it still restarts |
| `failed` during start | ✔ bails early, with the log attached |
| `failed` during **stop** is *not* an early bail | ✔ — `failed` means "not running", which is what a stop wants |
| Checksum mismatch | ✔ and a silent `sha256sum` is a failure, not a pass |
| Download failure, restart succeeds | ✔ the server comes back up regardless |
| Download failure **and** restart failure | ✔ both reported, download first |
| Restore with a missing main file | ✔ |
| Cross-target path rejection | ✔ before anything is stopped; a `worlds-evil` sibling is rejected too |
| First push to an empty slot | ✔ no backup, and that is not a failure |
| Rollback with and without a backup | ✔ both always restart |
| Rollback when the rollback itself fails | ✔ never throws |
| Backup failure | ✔ aborts *before* anything is overwritten |
| Verification failure | ✔ rolls back despite everything else succeeding |
| Missing game id | ✔ not a failure |

Design notes:

- **A progress sink, not a stream.** The original emitted global events and required
  listeners to attach *before* invoking, so events fired with nobody listening were simply
  lost — which is why switching tabs mid-push made the operation look like it had
  vanished. A callback handed over at call time cannot have that failure mode.
- **Timings are injectable.** `EnvelopeTimings.fast` runs the timeout paths in
  milliseconds, so "the stop never settles" is an ordinary unit test rather than a 30 s
  one. Production values are unchanged.
- **Streaming SHA-256.** The original read each world into memory twice — once to hash,
  once to upload; this streams both.
- **`extractFileToDisk` does not throw on a corrupt zip** — it silently extracts nothing.
  Without an explicit emptiness check the user would be told "no worlds found" and shown
  an internal temp path. It now reports an unreadable zip, and the "nothing here" message
  names the archive rather than the extraction directory.

---

### Phase 5 — Destructive UI ✅ **done, verified against the live server**

- `presentation/stepper.dart` — the pipeline, horizontal on desktop and a **vertical
  timeline** on a phone ([05](05-RESPONSIVE-UI.md#the-stepper--the-signature-element-and-the-hard-one)).
- `presentation/push_screen.dart`, `pull_screen.dart`, `library_screen.dart` — the three
  panels, with destructive confirmations that spell out what is about to happen.
- `presentation/file_pickers.dart` — folder flows gated on **platform**, not width
  ([04 §3](04-TRICKY.md#-3-file-system-idioms-dont-port-to-mobile)).
- `data/operations_controller.dart` — the lock, the progress logs that outlive their
  widgets, and the wakelock.
- Upload/download progress bars; the mobile "keep the app open" warning
  ([04 §2](04-TRICKY.md#-2-long-operations-vs-mobile-lifecycle)).

**Status: 397 tests passing**, analyzer clean, Windows and Android both build and the app
runs. 31 new tests cover the stepper at both widths and the controller's locking.

Design notes:

- **Structural assertions, not pixel goldens.** The plan called for goldens at 360 px and
  1440 px. Fonts are not yet vendored, so a golden would be comparing whatever monospace
  face each machine happens to have and would fail everywhere but the one that generated
  it. What actually matters — *which* layout is chosen, and which stage is marked how — is
  asserted exactly: the horizontal layout is verified by stages differing in x and not y,
  the vertical by the reverse. Revisit once fonts ship.
- **One source of truth for "busy", enforced by test.** `OperationsState.active` is set
  from the same `OperationLock` that gates execution, so a disabled button and a refused
  call cannot disagree. A test starts a slow push and asserts the second operation is
  refused *and* that the flag is already set synchronously.
- **`targetProvider` was extracted.** The controller previously reached into
  `connectionProvider`, which made it untestable without constructing a real `SshSession`
  (private constructor, needs a socket). Everything server-facing now depends on
  `ServerTarget?` instead, so a fake substitutes cleanly — and the layering is better for
  it.
- **A failure never wedges the app.** The lock is released in a `finally`, verified
  including the fire-and-forget call shape a button handler actually produces.

**Exit — met against the reference LXC** (`test/integration/live_destructive_test.dart`,
gated behind the `live` tag, a named profile **and** `WK_LIVE_DESTRUCTIVE=1`):

| Step | Result |
|---|---|
| Pull | `checkingService → stopping → downloading → starting → done`; 10,187,128 bytes; downloaded digest matched the server exactly |
| Push (same world back) | all nine states, no rollback; 5,093,476 bytes uploaded **over SFTP**; envelope's own `sha256sum` check passed; game id preserved; backup created holding `0.world.gzip` + its `.pugbackup` |
| Induced failure | `stopping → backingUp → copying → rollingBack → failed`; note `restored backup; restart issued`; **the rolled-back world matched the safety backup byte for byte** |
| Final state | service running, 1 UDP listener, game id `ckrN2fzdAw6MR7f` unchanged throughout |

Two findings from the live run:

- **SFTP works on this host.** It had been the one unverified assumption since Phase 2 —
  a hardened `sshd` can drop the subsystem, in which case push would have failed at
  upload. A 5 MB world transferred and verified.
- **A running Core Keeper rewrites its world on shutdown.** The first version of the
  destructive test asserted the live world stayed byte-identical throughout and failed on
  the very first step — the app was right and the test's premise was wrong: the game
  flushes a save when it stops. Byte-equality across a stop is not an invariant, and
  asserting it amounts to asserting the game does not save. The test now checks the
  invariants that actually hold: a pull matches what was on disk at that moment, a push's
  integrity is proven by the envelope's own checksum comparison, and **a rollback restores
  exactly the safety backup that operation took** — which is what rollback promises and is
  deterministic.

Also fixed while reading the live output: `sizeOf` summed `find -maxdepth 1 -name '*'`,
which matches the directory itself at depth 0, overstating every backup by its ~4 KB inode.
Inherited from the original.

---

### Phase 6 — Terminal ✅ **done, verified against the live server**

- `data/terminal_session.dart` — the PTY over `dartssh2`, wired to an `xterm` `Terminal`:
  keystrokes out, bytes in, and `onResize` forwarded as a window-change so full-screen
  programs redraw correctly.
- `data/terminal_controller.dart` — one session at a time, torn down on disconnect, and
  never opened automatically.
- `presentation/accessory_key_bar.dart` — the **mobile key bar**
  ([04 §6](04-TRICKY.md#-6-terminal-on-mobile)).
- `presentation/terminal_screen.dart` — themed to match the app rather than a black
  rectangle bolted onto a pale UI.

**Status: 415 tests passing**, analyzer clean, both builds green.

Live verification against the reference LXC (`live_server_test.dart`):

```
pty: prompt, command echo and resize all round-tripped
```

`echo` came back through the shell, `tput cols` reported **120** after a resize — proving
the window-change reaches the far side — and two `exec` calls ran concurrently with the
shell on the same connection, which is the multiplexing the whole design leans on.

#### Post-release fix: typing did not work on desktop

Shipped broken and caught in use: **Enter worked, letters did nothing** — on Windows only,
while Android was fine. Two distinct problems, in the order they were found:

1. A `focusNode` focused before `TerminalView` mounted. xterm opens its text-input
   connection from a focus-change *listener*; `CustomTextEdit.initState` only subscribes
   and never opens it for an already-focused node. Real, verified by test — but not the
   desktop cause.
2. The actual cause: xterm 4.0.0 attaches with the pre-multi-view `TextInput.attach` API,
   which Flutter 3.44 rejects on Windows with `Could not set client, view ID is null`. The
   connection can never open there, so characters have no route in at all. Fixed with
   `hardwareKeyboardOnly: true` on desktop — see [04 §6](04-TRICKY.md#-6-terminal-input--and-it-was-input-exactly-as-predicted).

The live test that "verified" this phase called `terminal.textInput(...)` directly, which
is not the route a keystroke takes, so it passed against a real server while the app was
unusable. Input is now tested through **both real routes** — `tester.sendKeyEvent` for the
desktop path and `tester.testTextInput` for the mobile one — since the app deliberately
uses a different one per platform.

Design notes:

- **Sticky modifiers, not latched.** Ctrl/Alt/Shift arm for exactly *one* keypress and
  then clear. Latching looks simpler and is a trap: a forgotten Ctrl turns the next `ls`
  into `Ctrl+L`. The armed state is shown, because an invisible mode is worse than no
  mode. Implemented by wrapping xterm's default input handler and *adding* the armed
  modifiers, so a desktop user's physical Ctrl is unaffected — covered by a test.
- **`^C`, `^D`, `^Z` get their own keys** alongside the sticky Ctrl. They are the ones you
  reach for under pressure, and two taps to interrupt a runaway process is one too many.
- **Renamed to `ShellSessionController` / `ShellState`.** xterm exports its own
  `TerminalController` and `TerminalState`; two same-named types in one file is a tax paid
  on every future edit.
- The screen is kept mounted by the app shell, so a half-typed command, a running `top`
  and the scrollback all survive navigating away — the reason `IndexedStack` was chosen
  back in Phase 3.

---

### Phase 7 — Audit UI ✅ **done**

- `core/audit/audit_queries.dart` — the read side, which had never existed: filtered,
  paged, typed drift queries for events / commands / errors, plus the facet lists and row
  counts.
- `core/audit/audit_export.dart` — a zip of one CSV per table **and** the raw database,
  streamed to disk rather than assembled in memory.
- `features/audit/` — three views with filters, 300 ms debounced search, expandable rows
  and a two-step clear.

**528 tests passing**, analyzer clean, both builds green.

Design notes:

- **Always exactly one server in scope, and the screen names it.** The database spans every
  machine the app has ever touched, and an unscoped list read as one server's record while
  the header named another — the one failure mode a forensic log cannot have.
  - **Connected it is locked** to the connected host. Reading one machine's log while
    operating on another is how you convince yourself the wrong thing happened.
  - **Disconnected it is a picker**, listing the servers that have history. That is the
    case the record is most often wanted in — the host is unreachable and you want to know
    what was done to it — so it was wrong for the screen to go blank there, which is what
    the first version of this did. Defaults to the most recently used.
  - The list comes from the **log**, not from `config.json`: a profile configured this
    morning has nothing to read and offering it is a dead end, while a *deleted* profile's
    history stays reachable — deleting a profile is not meant to destroy the record of what
    was done to that machine. It shows as "Deleted profile" rather than a bare id.
  - Either way the scope drives every query, so the tab re-queries on connect, disconnect
    and re-pick without anyone pressing Refresh.
- **One session row per (app run × server).** Scoping surfaced a latent bug.
  `recordConnect` filled the profile into the row opened at startup, so connecting to a
  second profile in the same run *relabelled* a row already holding the first server's
  events — attributing them to the wrong machine and hiding them from the right one.
  `AuditSessionController` now rolls to a fresh row when the profile changes.
- **Records, not a grid.** The plan said table on desktop, cards on mobile. It ended up
  one expandable row widget that lays out differently at each width, because the payload
  is long text — a JSON blob, a stdout capture — not a set of column values. A `DataTable`
  would have meant truncating the interesting part on *every* screen size, then rebuilding
  the same expand-to-read affordance anyway.
- **Paging is exposed.** The backend has always supported `offset` and the original never
  surfaced it, so anything past the newest 200 rows was simply invisible. There is now a
  "Load more".
- **A null exit code is a failure.** A command that never returned a status hit a
  transport error; filtering it into the success bucket would hide exactly the rows worth
  finding. Tested.
- **Facets come from the data.** Kind and context dropdowns list what is actually present
  rather than a hard-coded set that drifts from reality.
- **The clear dialog says what it does *not* touch.** The original's clear silently made
  real, restorable backups invisible, because the World Library read them from the
  database. That is fixed at the source — the library lists from the filesystem — and the
  copy now says so, since the fear is reasonable and worth answering.
- **Clear follows the same scope the screen does — and the picker is what made it simple.**
  It deletes the server on screen and names it, in two confirmations. There is no checkbox,
  no opt-in and no third prompt, because there is no longer a case where "clear" could mean
  anything else: the scope is always one server, so the blast radius is always the thing
  you are looking at. An earlier version had a widen-to-everything checkbox costing a third
  confirmation, needed only because disconnected had no server to scope to;
  `clearAuditLog` and `confirmDestructiveWithOption` were deleted along with that case
  rather than left as reachable-by-nothing code.

Found by the phone-width widget test: `SectionHeader` put its actions beside the title and
overflowed by 152 px at 360 px, pushing the rightmost button off-screen. It affected every
screen using it — Push, Pull, Library, Terminal and Audit — and is now a column on compact.

Found by the disconnected-state widget test: `_tabs` was a lazy `late final`, and the tabs
only exist while connected — so a screen that never saw a connection *constructed* its
`TabController` inside `dispose`, where `SingleTickerProviderStateMixin` can no longer
reach `TickerMode`. Built eagerly in `initState` now.

---

### Phase 8 — Chrome & release ✅ **done**

Command reference, About dialog, disclaimer, keyboard shortcuts, theme toggle,
accessibility pass, localisation (en + fr), launcher icons, Windows installer, Android
release signing, CI.

**660 tests passing**, analyzer clean, `dart format` clean, Windows and Android release
builds green, and the Windows installer builds and is 12.7 MB.

#### Localisation

Every string a person reads while deciding what to do is in the ARB files — roughly 340
messages across every presentation file, plus the command reference. What is **not**
translated is the record: audit event kinds (`push_start`), the SSH commands themselves,
remote stderr, and the diagnostic text attached to a failure. The dividing line is whether
a string describes *the app* or *the server*; anything that comes back over the wire, or
goes into the audit database, is the server's. Three reasons, in order of what they cost:

1. The audit log is evidence. It is exported to CSV and read by someone who was not there,
   often on another machine in another language. A log whose rows change wording depending
   on who ran the app is not one you can compare against another.
2. Those strings are already in SQLite from earlier sessions. Translating at write time
   would make the history bilingual; at read time it would mean a lookup table keyed on
   strings that were never meant to be keys.
3. `sudo systemctl stop` has no French form, and a stderr line is the remote machine
   talking, not us.

The command reference *is* translated, all 55 distinct labels of it. It is the screen
someone reads before deciding whether to trust a button labelled "Push" with a machine
they care about, and leaving the most safety-relevant screen in English would be leaving
it out of the reach of the people it is for. The commands beside the labels stay verbatim.

**`gen_l10n` catches nothing that matters.** A missing translation does not fail the build
and does not throw — it silently falls back to English, so the French user gets an English
sentence with no indication anything is wrong. A *dropped placeholder* is worse:
`"Monde restauré"` compiles, runs, and simply never says which world. `arb_test.dart`
compares the two files directly: same key set both ways, same placeholders per message,
placeholder metadata present on every parameterised message in the source language, and no
string of 45 characters or more left byte-identical between them. Short strings coincide
legitimately — "Terminal", "Port", "OK", "Docker" — which is why the rule is a length
threshold rather than a difference check.

Two real bugs fell out of the pass. The audit filter dropdowns built their "no filter"
entry as `'All ${label.toLowerCase()}'`, which produced **"All session"** and **"All
kind"** — English grammar hard-coded into a widget, and wrong in English too. And
`formatUptime` appended `d` for days, which in French is `j`.

The language picker is a cycler beside the theme one: system → English → Français →
system. Languages are named in their own language, never the interface's — someone who has
cycled one step too far and cannot read the screen is looking for the word they recognise,
and "Anglais" is not it. "System" is the exception, because it names a setting rather than
a language.

**The first version of that control worked and looked broken**, which is worth recording
because the mistake is easy to repeat. It was `Icons.translate_outlined` in all three
states, with the current language only in the tooltip. So the *only* feedback needed a
mouse and a pause — none at all on a phone — and the first press of the cycle moves system
→ English, which on an English machine changes nothing else on screen either. One press in
three genuinely looked like a dead button, and the report was "it does not toggle". It did.
The theme button gets away with a cycle because each of its states has its own glyph; a
language has exactly one symbol, its code, so the button now shows `EN` / `FR` and keeps
the glyph only for "following the device". A test taps it three times and asserts three
different faces.

#### Icons, installer, signing

Launcher icons come from the original app's `icon.png`, vendored here as
`assets/icon/icon.png` so this project has no dependency on that one, through
`flutter_launcher_icons`, for Android (five densities plus adaptive layers), Windows and
macOS. The **adaptive foreground is inset 18%**, which is not cosmetic: the launcher picks
the mask, and the smallest one that must still show everything is a 72dp circle on the
108dp layer. The source art is a full-bleed circular badge with "WORLD KEEPER" running
around its top edge, and at the default 16% a circle mask shaves the lettering off. The
adaptive *background* is the app's own `oklch(0.16 0.008 250)`, asserted against the theme
by a test — an icon on a colour the app never uses looks like someone else's icon, and it
is the first pixel of this one anybody sees.

The Windows version resource said `world_keeper` in every human-facing field, which is what
Task Manager, the properties sheet and the SmartScreen prompt all read. Fixed to "World
Keeper"; the executable name is unchanged.

The installer is **Inno Setup, not MSIX**. An MSIX will not install at all without a
certificate the machine already trusts, so an unsigned one means talking the user through
importing a self-signed cert before they can try the app. An unsigned Inno installer shows
the SmartScreen prompt, which is what the Tauri build has always shown. Per-user by
default so there is no UAC prompt on top of that. `build.ps1` also **stages the Visual C++
runtime beside the executable** — Flutter's embedder links against it and the build does
not copy it, which is invisible on a developer machine because Visual Studio put the DLLs
in System32, and shows up on somebody else's as `VCRUNTIME140_1.dll was not found`.

`[UninstallDelete]` is deliberately empty, and a test asserts no instruction anywhere in
the script names `com.civortech.worldkeeper`. That directory holds config, generated SSH
keys and the audit log, and it is *shared with the Tauri build* — removing it would
destroy the other app's setup as a side effect of uninstalling this one.

**Two hours went to a PowerShell parsing bug worth writing down.** `powershell -File` is
Windows PowerShell 5.1, which decodes a BOM-less script using the ANSI code page — and
PowerShell's tokenizer accepts the smart quotes at 0x91–0x94 as real string delimiters. A
UTF-8 em dash inside a double-quoted string arrives as three bytes whose last one *closes
the string*; every string after it shifts by one, and the script fails somewhere unrelated.
What it actually said was `The variable '$pubspec' cannot be retrieved because it has not
been set`, pointing at a `Write-Host` line seven lines earlier. The script is now pure
ASCII *and* carries a BOM, and a test checks both, because either alone would have caught
it.

Android release signing reads `android/key.properties`, gitignored, with
`key.properties.example` committed. Absent, it falls back to the debug key so a fresh clone
can still `flutter run --release`. That fallback is right locally and catastrophic in a
release: a debug-signed APK installs, runs and looks entirely normal, and can never be
updated, because Android refuses a properly-signed build over it — every user who installed
one would have to uninstall, losing their profiles and audit log, to move across. A warning
is not enough, because Flutter swallows Gradle's output unless you pass `-v`, so
`-PrequireReleaseSigning` makes the build **fail** instead. The release workflow always
passes it.

#### CI

`ci/github-workflows/` — analyse + format + generated-file staleness on Linux, the test
suite on Windows, then both release builds. A tag builds signed artifacts and opens a
*draft* release.

Tests run on Windows rather than Linux because the audit database is SQLite through a
native asset and the suite has only ever been verified against the Windows build of it;
running it where the app is never shipped would be testing a configuration nobody uses.

The three staleness checks — localisations, launcher icons, drift/freezed output — all
**regenerate and diff**. Stale generated output is not something a test can detect: it is
valid, it just describes the previous version of the source. Regenerating and asserting the
tree did not move is the only exact check there is.

The workflows are **not at the repository root**, because the root still belongs to the
Tauri app and its own release workflow. They are written for that location — both set
`working-directory: flutter` — and go live with one `cp`. See [ci/README.md](../ci/README.md).

#### Fixes from running it on real hardware

Two from a phone against two real servers:

- **The worlds path was only ever searched under `/home`, and only as world *files*.** Both
  halves were wrong. A single-purpose LXC runs the server as `root`, so `_launch.sh` sits in
  `/home/steam` while `$HOME` is `/root` — the worlds are somewhere `find /home` will never
  look. And a server that is installed and running but has never saved has the directory
  with nothing in it, so a file search reports "none found" on a perfectly healthy host.
  Now: resolve the user the process *actually* runs as (`ps -o user= -p <pid>`) and their
  real home from the password database rather than assuming `/home/<user>`; search `/home`,
  `/root`, that home and a systemd unit's `WorkingDirectory`; and fall back from files to
  `-type d -name worlds` when no world has been written yet.
- **The connection sheet stayed up after connecting**, so the thing you had just connected
  to was behind it. It now dismisses on the *transition* into connected — not on the state,
  because the sheet is also how you disconnect — and stays put on failure, where the error
  belongs beside the controls that produced it.

**Android release builds could not connect at all.** Flutter's generated scaffold declares
`INTERNET` in `src/debug` and `src/profile` only, for hot reload — so every kind of
development works and the shipped APK fails at `connect()` with `EPERM`, surfacing as
`SocketException: Operation not permitted, errno = 1`, which reads like a firewall or a
routing problem. No widget test can catch it: tests run on the host and release builds are
never exercised. `internet_permission_test.dart` now asserts it against the manifest file,
along with the launcher label and the fact that nothing beyond the network is requested —
an SSH client that also asks for storage is one people are right to distrust.

**Fonts: deliberately not vendored.** Geist / Geist Mono / JetBrains Mono ship from
fontsource as `.woff2` only, which Flutter cannot load, so matching the original exactly
would mean converting them or pulling new binaries in. Every target platform already has a
good monospace face; `monoFontFallback` uses it and looks native rather than nearly-right.

#### Decisions from the chrome pass

- **The command reference is tested against the code it documents.** A static list of
  "commands this app runs" is a comment that looks like a contract: it keeps asserting
  whatever it said the day it was written while `ssh_target.dart` moves on underneath, and
  the person reading it before approving a destructive operation is the one who pays.
  `command_reference_test.dart` runs the real `SshTarget` against a recording transport for
  each `ServiceKind` and asserts every command it produced appears verbatim in the
  reference. It caught a discrepancy on its first run: `pgrep` shell-quotes the captured
  process command line, while `start`/`stop` send theirs raw, and the reference showed one
  form for both.
- **The reference substitutes *and* quotes.** Discovered values appear exactly as they are
  sent — `find '/home/steam/Core Keeper/worlds'` — so a line can be pasted into a terminal
  and mean the same thing. Placeholders stay unquoted, because `find '<worlds_path>'` looks
  runnable and is not.
- **The disclaimer is re-readable.** The original showed it once and had no route back to
  it. A warning you cannot re-read is a worse warning, so it is in the menu; re-opening it
  is an ordinary dismissible dialog, since re-reading is not re-consenting. The `.v1`
  storage suffix is kept and is load-bearing — bumping it re-asks everyone, because an
  acknowledgement of different text is not an acknowledgement of this text.
- **Nothing destructive has a keyboard shortcut.** Navigation (`Ctrl+1`…`9`) and help
  (`F1`) only. A keystroke that stops a game server and overwrites world files is one
  somebody eventually hits by accident, and the whole safety story here is that those
  actions are deliberate and confirmed. The help sheet says so, and a test asserts it.
- **The theme toggle finally exists.** `ThemeModeController.cycle()` had been written in
  Phase 1 and was never wired to any UI — three phases of screens shipped with no way to
  call it. Found while placing the About button.

The accessibility pass was where the bugs were. Everything below was found by pumping the
app at 200% text scale, which is the setting people actually use, not an edge case — and
none of it throws, so all of it was invisible until asserted:

- **The bottom bar carried seven destinations where Material caps at five.** At 360 px each
  gets 51 px, so "Discovery" and "Terminal" were unreadable before any accessibility
  setting was involved, and at 200% the bar overflowed by 76 px. Now four plus a "More"
  sheet — which is what [05-RESPONSIVE-UI](05-RESPONSIVE-UI.md) specified and Phase 6 did
  not implement. The "More" slot shows the *current* destination's name when the screen
  behind it lives in the sheet, so the highlight never contradicts what is on screen.
- **The connection chip ate the compact app bar.** "Disconnected" at 200% is ~140 px, which
  with two icon buttons left the title 94 px of 360. It is now a bare dot on compact, with
  the words moved to `Semantics` — a screen reader gets more than it did before, not less.
- **Fixed heights that ignore text scale.** A text-only `Tab` is pinned at 46 dp by
  Material, the terminal's accessory key bar at 48; both overflowed. Both now scale with
  `MediaQuery.textScalerOf`.
- **`Center` clips, it does not scroll.** Every empty state — "Not connected", "No session",
  the audit notice — was taller than its box at 200% on a phone, so the user with large
  text was exactly the user who could not read the explanation of why the screen was empty.
  `CenteredNotice` centres when it fits and scrolls when it does not.
- **The audit filter bar was taller than the tab view it sat in** (~364 px of controls in
  ~298 px at 200%). The view is now one `CustomScrollView` with the filters as the first
  sliver, which fixes it at every scale and hands the rows the room on a phone regardless.
- **Success and failure were signalled by colour alone** — a coloured dot, in a forensic log
  whose whole purpose is answering "did that step work". Nothing to a screen reader, and
  nothing to a red/green-deficient reader either. The dot now carries a label.

Material's own `textContrastGuideline`, `androidTapTargetGuideline` and
`labeledTapTargetGuideline` all pass at both widths — those are real checks, not assertions
of intent. Reduced motion needed nothing: the stepper's pulse is the only decorative motion
in the app and it already honoured `disableAnimations`.

---

### Phase 8.1 — Making the app say what it did

Three separate reports of "this is broken" turned out to be three instances of the same
thing: a control that worked and declined to mention it. The language button (above) was
the first. These are the other two.

**Discovery now shows its work.** `DiscoveryProbe` records every command it sends —
text, exit status, stdout, stderr, duration — and the screen renders them in a collapsed
"What the probe did" panel with a copy-to-clipboard button. `_exec` wraps `_transport.exec`
so a step cannot be added without being logged.

The reason this is worth the machinery: **"Worlds path — none found" is true and useless.**
It does not distinguish "searched three roots, nothing there" from "`find` exited 127 and I
could not search at all", and those have opposite fixes. The panel marks the three outcomes
differently — ran and found something, ran and found nothing, could not run — because the
middle one is a correct answer and the last one is our bug. Before this, the only way to
tell them apart was to open an SSH session, which is the thing a discovery screen exists to
spare you.

It is deliberately **not** the audit log. That is the record of what the app did to a
server, kept for export and for reading months later; this is a working note about the
screen in front of you, discarded with the result. Keeping them apart is what lets the
trace hold full `find` output without bloating a database meant to be shared.

**What the transcript found on its first run.** Three faults on one host, only one of which
was the one being looked for — and none of them diagnosable before the panel existed.

- **The probe was finding itself.** `pgrep -f _launch.sh` matches against the whole command
  line, and the command line *contains the pattern*, so the server and the probe's own
  `bash -c pgrep …` came back together. Which one landed first was down to pid ordering.
  Picking ours would have built a target whose "start the server" command was a pgrep and
  whose `pkill -f` stop command targeted our own shell. It happened to pick correctly on
  this host; nothing made it do so.
- **`ps -o user=` returned `101000`, not a name**, and `getent passwd 101000` returned
  nothing. That is the host-side uid of an unprivileged LXC's user, and it left `homeDir`
  null — so the search collapsed back to `/home` and `/root`, which is exactly the case the
  previous fix was supposed to handle. The password database is simply not an answer here.
  The probe now reads `HOME` and `XDG_CONFIG_HOME` out of `/proc/<pid>/environ`, which is
  the process's own environment and the only authoritative source: a launch script may set
  either to anything, and neither has to agree with `/etc/passwd`.
- **A server in another mount namespace cannot be found by searching harder.** If the SSH
  session is on a Proxmox host and Core Keeper runs inside a container, `pgrep` reports the
  command line it was started with — so the service looks perfectly detected — while every
  path in it belongs to a filesystem this session cannot see. `readlink /proc/<pid>/root`
  says so in one command, and the screen now names the situation instead of reporting
  "none found" about a server that is running fine.

Search roots are now, best evidence first: the process's `HOME`, its `XDG_CONFIG_HOME`, its
working directory, the directory holding its launch script, then `/home` and `/root` as the
blind guesses at the end.

**The second transcript from the same host ruled out the obvious answer and found two
more.** `readlink /proc/<pid>/root` returned `/` — no container, and the screen correctly
said nothing rather than guessing. `HOME=/home/steam`, which the search already covered.
Every `find` exited 0 with no output. So there is no worlds directory and no world file
anywhere under `/home`, on a server that is running.

- **Only the wrapper was ever probed.** A Core Keeper install is a `_launch.sh` that execs
  the game binary, and the two answer different questions: the wrapper is what you start
  and stop, the binary is what writes the worlds. The probe ran
  `pgrep -af _launch.sh || pgrep -af CoreKeeperServer` — and `||` short-circuits, so on any
  host with a wrapper the binary was never looked at. A launch script that exports `HOME`
  before exec'ing makes the wrapper's environment — the shell's, from before the script
  ran — the wrong answer entirely. Both are probed now, and the binary's environment wins.
- **A server that has never saved has nothing to find.** Searching cannot produce a path
  that is not on disk, and the screen's answer to that was a blank text field, which asks
  the user to know a Unity directory layout by heart. Core Keeper's location is *derivable*
  from the environment — `$XDG_CONFIG_HOME` or `$HOME/.config`, then
  `unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds` — so with `HOME` in hand the field
  is now pre-filled with it and labelled as a suggestion to confirm rather than a finding.
  It stays out of `worldsPath` and `worldsPathCandidates`, which mean "the host confirmed
  this exists".
- **The failure path now lists rather than searches.** When everything comes back empty the
  probe runs one `find $HOME -maxdepth 6 -type d | head -100` into the transcript. A search
  cannot distinguish "never saved" from "installed somewhere unexpected"; a listing can,
  and it costs one command on the path that was going to say "none found" regardless.

**Then the transcript exposed a hole in itself.** The desktop build found two systemd units
on a host where the phone build, minutes later, found none — and both transcripts said the
same thing: `exit 1`, no output. The command was
`systemctl list-units --type=service 2>/dev/null | grep -i core`, and every part of it hid
something:

- **A pipeline's exit status is the last command's**, so `systemctl` failing and `grep`
  matching nothing arrive identically as exit 1.
- **`2>/dev/null` discards the one thing that would say which.**
- **Filtering in the shell** means the transcript never shows what systemd replied, so "no
  unit matched" cannot be told from "no units listed at all".

Every discovery command now filters in Dart and keeps its stderr. `find` is the single
exception and keeps `2>/dev/null`, because permission-denied on every unreadable directory
is noise rather than signal. `pgrep` and `docker` are marked as commands whose non-zero
exit is an *answer* — nothing matched, not installed — so a healthy systemd host does not
show three red markers. The listing also gained `--all`: a Core Keeper unit that is loaded
but stopped is exactly the one you want to find, and is the most plausible reason the two
runs disagreed.

The general lesson, which cost two round trips to learn: **a diagnostic that pipes into
`grep` and redirects stderr is not a diagnostic.** It reports the filter's opinion of the
answer, not the answer.

**Confirm now reports.** It wrote the discovery, unlocked five screens, and showed nothing
— the only visible change was an 8px dot in the app bar going red to teal. It now shows a
spinner while writing, then replaces the form with a receipt naming the three values now
stored against the profile, what they unlocked, and a Change button back to the form.
Re-probing clears it, since a stale success panel would claim the new findings were saved.

---

### Phase 8.2 — Key auth, and refreshing on demand

**"Set up key auth" was never ported.** The Rust app has it; `SshSession.installPublicKey`,
`AppPaths.keysDir` and the command reference entry were all carried over, and the button
and the key generation were not. That gap is the real answer to "remember my password on
Android": on desktop nobody was remembering a password either — they had clicked this once
and never been asked again. `savePassword` is dead code in *both* apps.

A key is the better answer anyway. It is per-host, revoked by deleting one line on that
host, and the secret never travels — only the public half is sent. A stored password is the
same secret, reusable wherever it was reused, sitting in a credential store.

Ed25519 via `cryptography` (already a dependency), encoded with `dartssh2`'s own
`OpenSSHEd25519KeyPair.toPem()` so the file is written by the same library that will read
it back. **The order matters and is the whole safety argument**: the key goes onto the
server *before* the profile switches to key auth, because the reverse leaves a profile that
cannot connect at all — key auth against a host that never received the key, with the
password no longer being asked for. An installed key that goes unused is harmless; the
opposite is a locked door.

`key_generator_test.dart` round-trips through `SSHKeyPair.fromPem` — the same parser
`connectWithKey` uses — and verifies a real signature with **`cryptography` rather than
`dartssh2`**, since asking the library that signed to check its own work would pass even if
its notion of an Ed25519 key disagreed with everyone else's. A malformed pair otherwise
writes a file, uploads a line, switches the profile, and fails on the *next* connect, by
which point the password may be the thing you no longer have.

Deleting a profile now deletes its key: an orphaned private key in the data directory is a
credential nothing can explain. The line in the server's `authorized_keys` is deliberately
**not** removed — the app cannot reach a server it no longer has a profile for, and the
delete dialog says so rather than implying otherwise.

**Stats gained both a refresh button and pull-to-refresh**, which is not redundancy: the
gesture is what a phone user reaches for and is invisible to a mouse, and the button is the
reverse. Two details that would each have made it feel broken — `AlwaysScrollableScrollPhysics`,
without which the pull silently does nothing whenever the readings happen to fit the screen;
and rendering from `AsyncValue.value` rather than `when`, because Riverpod reports a
re-fetch as loading *with* the previous value attached, so the obvious code blanks the whole
panel every time a manual refresh overlaps a poll.

---

### Phase 9 — Improvements the rewrite enables

Explicitly *not* parity work. Sequenced last so parity is never blocked on them.

**What is still open — including the one item that turned out to matter most, teaching the
app to explain itself — is written up with build and test notes in
[TODO.md](../TODO.md).** This section records what was done and why.

1. ~~**Resumable/recoverable envelope**~~ ✅ **done** — see below.
2. ~~Finish or delete `savePassword` and the `file_ops` table~~ ✅ **done** — see 9.2.
3. Real `-f` log streaming over a dedicated channel, replacing polling.
4. ~~Audit pagination in the UI~~ ✅ — it was built in Phase 7 and simply never *tested*;
   see 9.2.
5. Steam build-id badge (SPEC §10 stretch, never built).

#### 9.1 — Recovering an interrupted operation

Push, pull and restore all **stop the game service and start it again**. Between those two
points the server is down, and if the app stops running in that window — Android freezing a
backgrounded process, a laptop lid, a kill — nothing starts it back up. That was the one
remaining way this app could leave a server broken and say nothing.

`OperationJournal` writes a marker to `interrupted-operation.json` when the window opens,
updates it as the operation moves through, and deletes it when the window closes. Its mere
existence at connect time means the last operation never reported a result.

- **A file, not an audit row.** The audit log is clearable by the user, and losing recovery
  information as a side effect of tidying a log would be a nasty surprise. It also has to
  survive a process that was killed outright, where a buffered database write would not
  have landed.
- **The window opens at `stopping`, not at the start.** Everything before it — the upload
  into a staging directory — leaves the service running, so an interruption there costs
  time and nothing else. Warning about those would train people to dismiss the warning that
  matters.
- **It closes on `failed` as well as `done`,** because the envelope's rollback restarts the
  service as its last act. By the time `failed` is reported, the app no longer owes anyone
  a running server.
- **The three envelopes are three unrelated enums** that happen to agree on `stopping`,
  `done` and `failed`. That is a coincidence until something enforces it — rename one and
  the marker silently never opens for that operation — so a test asserts all three.

The prompt **asks the server rather than assuming**. The marker says an operation was
interrupted, not that the service is down; the process may have been killed a millisecond
after the start command landed. And it is deliberately **not a resume**: re-running a
half-finished swap without knowing which half finished is how a world gets overwritten with
a partial copy. Starting a stopped service is safe and is almost always the whole fix;
anything more is a restore from the World Library, which has its own confirmations.

**A testing trap worth recording.** `testWidgets` runs against a fake clock, and real
asynchronous work — file I/O included — never completes unless given a turn on the real
event loop via `tester.runAsync`. Awaiting `File.delete()` inside a widget interaction does
not fail; it simply never returns, and the test hangs until the suite timeout with no
indication of where. Two tests burned ten minutes each before that was clear.

#### 9.2 — Finishing or deleting the leftovers

Three items that all read as "dead code" and were three different answers.

- **`savePassword` on the model: kept, and now says why.** It looked deletable and is not:
  `config.json` is read by both builds, the Rust one writes this key, and dropping it makes
  a profile that no longer round-trips — which `real_install_compat_test` exists to catch.
  It is carried, never acted on, and the doc comment says so. The answer to "stop asking me
  for a password" is key auth.
- **`SecretsRepository`: deleted.** Fully written, wired to a provider, and read by nothing.
  Key auth (8.2) answers the same question better — per-host, revocable server-side, and
  the secret never travels — so this was the half to drop.
- **`file_ops`: finished, because it was covering a real hole.** SFTP transfers are the one
  step of a push or pull that leaves **no trace anywhere**: everything else is a shell
  command and lands in `ssh_commands`, but a transfer is not a command. The log recorded
  that a push happened, which phases it went through and what the result *claimed*, and had
  no row saying the file moved. The table the Rust app used for exactly this was being
  imported from and never written to. Both envelopes now write one row per transfer,
  best-effort — the bytes are already across by then, and losing the note must not fail an
  operation that worked.

**Audit pagination turned out to be built already** — `loadMore`, `hasMore` and a "Load
more" button have been there since Phase 7. What was missing was any test, and the two
worth having are not the obvious ones:

- *At the query layer:* paging through a profile's events returns exactly the same rows as
  asking for them all at once. Every other scoping test reads page one, and a filter that
  lost its `profileId` in the `offset` path would show one server's history correctly and
  then splice another's in underneath.
- *At the UI layer:* only that the button appears and works. Counting rendered rows proves
  nothing — the view is a `CustomScrollView` and its slivers are lazy, so the number of rows
  in the tree is how many are on screen, not how many were fetched.

Two hours went into that UI test for a reason worth writing down: **`find` cannot see a
lazily-built sliver that has never been laid out**, so the button reads as absent until you
scroll to it; and `tester.drag` on a *row* stops working the moment the list moves, because
the row's centre leaves the viewport and the pointer lands outside the scrollable. Forty
drags moved the list by two rows. Dragging the *view* works.

**A bare process can now find its log.** systemd has the journal and Docker has its own log
by construction; a launch script redirecting to a file was the one shape with nothing to
read — and that target had no live log *and* no game id, since the id is parsed out of the
log. The probe looks one level deep beside the launch script and in the working directory,
and takes the answer only when there is exactly one: a live log panel confidently tailing
the wrong file is worse than an empty one. Discovery shows an optional field for the rest,
and `logsTail`'s error now names it rather than saying "no log file to tail".

---

## Decisions worth confirming before Phase 1

1. **Config compatibility** — is byte-compatibility with the existing `config.json` and
   audit db wanted (both apps coexist, zero-friction switch), or is a clean break fine?
   *Assumed: compatibility wanted.* It's cheap now and expensive later.
2. **Mobile scope** — full parity including push/restore from a phone, or a read-mostly
   mobile experience (stats, logs, terminal, restore) with pushes desktop-only? This
   materially changes how much of [04 §2](04-TRICKY.md#-2-long-operations-vs-mobile-lifecycle)
   is required. *Assumed: full parity, with the warning + keep-awake mitigations.*
3. **iOS/macOS** — build them now (needs a Mac, and Apple signing), or Windows + Android
   + Linux first? *Assumed: the latter; the platform folders exist either way.*
