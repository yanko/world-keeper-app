# World Keeper — Flutter Rewrite Plan

The plan this project was built to, written before any code. Kept as a record of what was
intended, next to [docs/06 — Build Order](docs/06-BUILD-ORDER.md), which records what
actually happened.

It set out to rewrite **World Keeper** — then a Tauri v2 (Rust) + React/TS desktop app —
as a single Flutter codebase that is **desktop-first and genuinely usable on mobile**. The
original lives in its own repository and was never modified; it still works.

---

## Documents

| # | Document | What's in it |
|---|---|---|
| 01 | [Feature Inventory](docs/01-FEATURE-INVENTORY.md) | Every feature, command string, timeout and edge case in the app **as built** — read out of the source, not the spec |
| 02 | [Architecture](docs/02-ARCHITECTURE.md) | Pure-Dart backend, layering, the `ServerTarget` seam, state management, concurrency |
| 03 | [Dependencies](docs/03-DEPENDENCIES.md) | The package stack — **verified by building, not by reading pub.dev** |
| 04 | [Tricky Bits & Risks](docs/04-TRICKY.md) | What's genuinely hard, with recommendations + a risk register |
| 05 | [Responsive UI](docs/05-RESPONSIVE-UI.md) | Breakpoints, navigation shell, per-screen behaviour, quality floor |
| 06 | [Build Order](docs/06-BUILD-ORDER.md) | Nine phases, each demoable; risky parts first |

---

## The headline decision

**Reimplement the backend in pure Dart. Do not keep the Rust core behind FFI.**

The Rust is good and correct, and reusing it via `flutter_rust_bridge` is tempting. It's
the wrong call, for one reason that dominates everything else: **the brief says mobile.**
Keeping Rust means cross-compiling `russh` + `sqlx` + `keyring` for five Android/iOS ABIs,
wiring NDK and Xcode into CI, and debugging across an FFI boundary — for a Rust layer
that exists largely because Tauri needed a backend for a webview, a constraint Flutter
removes outright.

Every capability has a mature pure-Dart equivalent, and I verified them rather than
assuming: **`dartssh2` 2.22.4** (password/key auth, full SFTPv3, PTY, channel
multiplexing, key exchange offloaded to isolates) is actively maintained — 2.22.4 was
published the day this was written.

The single genuine gap is Ed25519 **OpenSSH key generation**: no Dart package writes the
`openssh-key-v1` private key format. That's ~120 lines of well-documented binary
encoding, and it's testable by round-tripping through `dartssh2`'s own parser.

---

## What I verified, and what it cost

I didn't plan this against package descriptions. I scaffolded the project, resolved the
real dependency graph, wrote a [smoke test](lib/main.dart) touching a real symbol from
every critical package, and built it. That surfaced **four problems a paper plan would
have shipped as surprises**:

1. **`riverpod_generator` ⨯ `drift_dev` — unresolvable.** Conflicting `analyzer` majors.
   Forced a real choice; drift's codegen wins because it buys database *migrations*,
   Riverpod's only buys syntax sugar. → Riverpod without code generation.
2. **`sqlite3_flutter_libs` is discontinued** (`0.6.0+eol`, "no longer does anything").
   → `drift_flutter`.
3. **`path_provider_android` ≥ 2.3.0 breaks the Android build** — pulls `package:jni`,
   whose Gradle file is broken under AGP 9. → pinned to 2.2.23.
4. **Flutter 3.44's AGP 9 template splits the plugin ecosystem in half.** `file_picker`
   and `jni` assume AGP 9's built-in Kotlin compiles their sources;
   `flutter_plugin_android_lifecycle` applies `kotlin-android` unconditionally, which
   AGP 9 rejects when built-in Kotlin is on. **No value of `android.builtInKotlin`
   satisfies both.** → pinned AGP 8.11.1 / Gradle 8.14 / Kotlin 2.2.20, the only
   consistent point (and Flutter's stated minimums, so the build stays warning-free).

Also caught: `file_picker` 11 and `csv` 8 both changed their public APIs from what most
documentation still shows.

**Verified on this machine:**

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter build windows --release` | ✅ `world_keeper.exe` |
| `flutter build apk --debug` | ✅ `app-debug.apk`, no warnings |
| macOS / iOS / Linux | Not verified — no runner available here |

---

## What carries over unchanged

The existing design has three ideas worth protecting, and the rewrite keeps all three:

- **The `ServerTarget` seam.** One interface; all systemd/Docker/process branching behind
  it; the push/pull/restore state machines target-agnostic. In Dart, `ServiceKind`
  becomes a **sealed class**, so the compiler now enforces that a fourth kind updates
  every command site — strictly better than the Rust enum.
- **The safe envelope.** stop → back up → operate → restart → verify, with rollback on
  any failure. Ported step for step, including every timeout and the exact-pair backup
  rule.
- **Discovery over declaration.** Probe the host, never auto-apply, always confirm.

Plus the design language: cool slate base, **one** signal colour for live/healthy,
destructive red reserved for stop/rollback, mono for machine data.

## What gets better

Not goals in themselves — things that fall out of the move and are worth taking:

- **Tests.** The current codebase has **zero**. The `ServerTarget` seam makes a
  `FakeTarget` trivial, so the whole envelope — timeouts, rollback, the
  restart-after-failed-download path — becomes testable with no server.
- **Database migrations.** Today's schema is `CREATE TABLE IF NOT EXISTS` and nothing
  else; adding a column would break existing installs at runtime. Drift fixes this.
- **Progress events can't be lost.** The current design emits global Tauri events and
  subscribes before invoking; a listener that isn't mounted misses them (this is why
  `OperationsProvider` and `keepMounted` exist). Streams + Riverpod remove the class of
  bug.
- **Streaming transfers.** The Rust reads whole files into memory twice (hash, then
  upload). Dart streams both — and gets a real progress bar.
- **One lock, not two.** Today the Rust `operation_lock` and the React
  `activeOperation` are parallel mechanisms that can in principle disagree.
- **Typed errors.** The failing step becomes a field rather than prose in a string.

---

## The five things that are actually hard

Full detail in [04-TRICKY.md](docs/04-TRICKY.md).

1. 🔴 **SSH key generation** — no `ssh-keygen` on mobile, and no Dart package writes the
   OpenSSH private key format. Hand-roll `openssh-key-v1`; verify by round-tripping.
2. 🔴 **Long operations vs. the mobile lifecycle** — backgrounding kills the socket. If
   that lands between "Stopping" and "Copying", the server is left **stopped with no
   rollback**. Warn + keep-awake now; a resumable envelope is the real fix (and closes
   the same gap on desktop, where a closing laptop lid does this today with no recovery).
3. 🟠 **`find -printf` is GNU-only** — absent on BusyBox/BSD, where listings silently
   return *empty* rather than erroring. Probe capabilities at discovery time.
4. 🟠 **Mobile file-system idioms** — "pick a folder" and "save as a folder" don't exist
   on phones. Gate those flows on platform, not width.
5. 🟠 **Mobile terminal input** — no Esc/Ctrl/arrows. An accessory key bar is mandatory,
   not polish; without it you can't exit `vim` or interrupt a process.

One more worth raising even though it's pre-existing: **host keys are not verified at
all** (`check_server_key` returns `Ok(true)`). Defensible on a LAN; much less so once a
phone carrying a root shell roams onto untrusted networks. TOFU pinning is a small
change and I'd fold it into Phase 2.

---

## Three decisions I need from you

I've assumed answers so the plan is complete either way — but these change real work:

1. **Config compatibility.** Read the existing `config.json` and `ckmanager.db` so
   profiles and audit history carry over and both apps can coexist?
   *Assumed: yes* — cheap now, expensive to retrofit.
2. **Mobile scope.** Full parity including push/restore from a phone, or read-mostly on
   mobile (stats, logs, terminal, restore) with pushes desktop-only? This decides how
   much of risk #2 is mandatory. *Assumed: full parity, with mitigations.*
3. **iOS/macOS now or later?** Needs a Mac and Apple signing. *Assumed: Windows +
   Android + Linux first;* the platform folders exist regardless.

---

## Next step

Phase 0 is done. Phase 1 (models, config repository, audit database — no UI) is ready to
start on your word.
