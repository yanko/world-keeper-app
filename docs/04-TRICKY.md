# 04 — Tricky Bits & Risks

Ordered by risk × effort. Everything not listed here is a straightforward port.

Legend: 🔴 needs a real decision or has no clean answer · 🟠 solvable, non-trivial effort
· 🟢 known quantity, just fiddly.

---

## 🔴 1. SSH key generation

**Today:** shells out to `ssh-keygen -t ed25519`.

**Problem:** there is no `ssh-keygen` on Android or iOS, so the single most useful
onboarding feature ("stop typing your password") has no subprocess to call on half the
target platforms.

**Ecosystem state (checked):** `cryptography` generates Ed25519 keypairs fine, and
`dartssh2` *parses* OpenSSH keys — but **no Dart package writes the OpenSSH private key
format**. `ssh_key` handles public keys only and can't even extract Ed25519 params.

**Approach:** hand-roll the `openssh-key-v1` container. It's a well-documented,
stable, unencrypted-path-only format:

```
"openssh-key-v1\0"
string  ciphername = "none"
string  kdfname    = "none"
string  kdfoptions = ""
uint32  nkeys      = 1
string  publickey  = [string "ssh-ed25519"][string pub(32)]
string  privatekey = [uint32 check][uint32 check]          # two equal random words
                     [string "ssh-ed25519"][string pub(32)]
                     [string priv(64) = seed||pub]
                     [string comment]
                     [pad 1,2,3,… to 8-byte boundary]
```
…then base64, wrapped at 70 chars between `-----BEGIN/END OPENSSH PRIVATE KEY-----`.

~120 lines including an SSH-wire `string`/`uint32` writer that the SFTP layer can share.

**Verification is mandatory and easy:** round-trip every generated key through
`SSHKeyPair.fromPem()` in a unit test, and — on desktop, where it exists — assert
`ssh-keygen -y -f <key>` reproduces the same public key. Getting this subtly wrong
produces a key that silently fails to authenticate later, which is a miserable bug.

**Extra:** file permissions. On desktop the private key must be `0600` or OpenSSH
tooling will refuse it; Dart has no `chmod`, so use `Process.run('chmod', ...)` on
POSIX and ACL inheritance on Windows (the current app writes to the app data dir and
never chmods — arguably already a latent issue).

---

## 🔴 2. Long operations vs. mobile lifecycle

**Today:** a push runs inside one Tauri command on a desktop app that is never suspended.

**Problem:** a push is genuinely long — 90 s game-id timeout + 90 s verify timeout + a
multi-megabyte SFTP upload. On mobile, backgrounding the app suspends the Dart isolate
and **kills the TCP socket**. If that happens between "Stopping" and "Copying", the
user's server is left **stopped with no rollback**, which is the single worst outcome
this app can produce.

This is not theoretical — it's a phone call arriving mid-push.

**Mitigations, in order of value:**

1. **Make the danger window explicit.** Before starting a destructive op on compact,
   warn: "Keep the app open — backgrounding may interrupt this." Cheap, honest.
2. **Server-side resilience.** After reconnect, detect an interrupted operation (a
   `.staging` dir plus a stopped service, or a sentinel file written on the remote at
   envelope entry) and offer to resume/roll back. This is the *real* fix and it also
   makes the desktop app more robust — a laptop lid closing has the same effect today,
   with no recovery path at all.
3. `WakelockPlus` to keep the screen on during an operation.
4. Android foreground service for the duration. Meaningful work; iOS has no equivalent,
   so it doesn't remove the need for (1) and (2).

**Recommendation:** ship (1) + (3) with mobile, and treat (2) as a genuine improvement
over the current app rather than mobile-only scaffolding.

---

## 🟠 3. File-system idioms don't port to mobile

`getDirectoryPath()` technically exists on Android/iOS but means something different
(SAF tree URIs, sandboxes) — "save the pulled world as a folder" is not a mobile idiom,
and neither is "pick the folder containing my world files."

| Flow | Desktop | Mobile |
|---|---|---|
| Push: pick file | file picker | file picker (SAF) ✔ |
| Push: pick folder | folder picker | **hide** — offer .zip only |
| Pull: save as folder | folder picker | **hide** |
| Pull: save as .zip | save dialog | `saveFile` / share sheet ✔ |
| Audit export | save dialog | share sheet ✔ |
| "Show in folder" | `explorer`/`open`/`xdg-open` | **hide** |

Gate on `WindowSize` **and** `Platform`, not width alone — a tablet is compact-width but
still has no folder semantics.

Also: `%TEMP%/ckm-pull-<nanos>` becomes `getTemporaryDirectory()`, and mobile OSes can
evict it. Delete eagerly after packaging (the current code already does) and don't
assume the temp dir survives a background trip.

---

## 🟠 4. `find -printf` is a GNU-ism

`stat()` depends on:

```sh
find <dir> -maxdepth 1 -name <glob> -printf '%s %T@ %p\n'
```

`-printf` is **GNU findutils only**. It is absent on BusyBox (Alpine containers,
some NAS firmware), macOS/BSD, and toybox. The reference LXC and Unraid both have GNU
find, so this has never bitten — but this app's whole thesis is *target-agnostic
discovery*, and the pull/backup/restore listing silently returns **empty** rather than
erroring on a BusyBox host. Empty listings mean "no worlds found," which reads as a
different bug entirely.

**Recommendation (a real improvement, not just a port):** probe once at discovery time
and cache the strategy —

- GNU: keep the current `-printf` one-liner (fastest, one round-trip).
- POSIX fallback: `find <dir> -maxdepth 1 -name <glob> -exec stat -c '%s %Y %n' {} +`,
  and if `stat -c` is also unavailable, `ls -la` parsing as a last resort.

Add a `stat -c` vs `stat -f` (BSD) check to the same probe.

---

## 🟠 5. Audit database migrations

**Today:** `CREATE TABLE IF NOT EXISTS` and nothing else. There is **no migration
mechanism**. Any column added later silently doesn't exist on an existing user's db, and
the query will throw at runtime.

The rewrite must not inherit this. `drift`'s `MigrationStrategy` + schema versioning is
the reason drift won the codegen coin-toss against `riverpod_generator`.

**Also needed:** import the existing `ckmanager.db`. Users have real audit history. Ship
a one-time migration that opens the old file, verifies the six tables, and either copies
rows in or adopts the file wholesale at `schemaVersion: 1`. Preserve `sessions.id`,
because `backups.session_id` and the World Library's note-enrichment join depend on it.

---

## 🟠 6. Terminal input — and it was input, exactly as predicted

Covered in [05-RESPONSIVE-UI.md](05-RESPONSIVE-UI.md#terminal--the-biggest-mobile-gap).
The load-bearing part: **an accessory key bar is mandatory**, not polish. Without Esc,
Ctrl and arrows a mobile shell cannot exit `vim`, interrupt a runaway process, or use
`less`.

> "`xterm` handles ANSI/colour/cursor correctly … so rendering is not the risk — input
> is." That held, though not in the way expected: the breakage was on **desktop**.

### xterm 4.0.0 cannot attach a text input client on Flutter 3.44 desktop

xterm receives ordinary characters over a platform text-input connection, opened with the
pre-multi-view `TextInput.attach` API. Flutter 3.44 rejects that on Windows:

```
PlatformException(Bad Arguments, Could not set client, view ID is null.)
  at _PlatformTextInputControl.attach
```

`updateEditingValue` is therefore never called and **letters have no route into the
terminal at all**. Key events travel a different path — a plain `Focus` widget, no
connection needed — so Enter, arrows and Ctrl sequences all worked while typing did
nothing. Android was unaffected, which is what made it look like a focus bug.

**Fix:** `hardwareKeyboardOnly: true` on desktop, which swaps in
`CustomKeyboardListener` and reads `KeyEvent.character` directly. That is arguably better
there anyway — it is the character the OS says the key produced, so layouts and dead keys
are respected rather than re-derived from a US-centric key table. Mobile keeps the
text-input route, because a soft keyboard emits no hardware key events.

This is the `xterm 4.0.0 unmaintained (2 y)` row of the risk register coming due. The
widget is still worth keeping — rendering, escape parsing and selection are all correct,
and it sits behind one screen — but expect more of this, and note that **a version bump of
Flutter can break input without breaking the build**.

### The lesson for testing

The original live test drove `terminal.textInput(...)` directly, which is not the route a
keystroke takes. It passed against a real server while the app was unusable. Input is now
tested through both real routes — `tester.testTextInput` for the mobile connection and
`tester.sendKeyEvent` for desktop key events — because the app uses a *different one per
platform*, and testing one would have missed this again.

---

## 🟠 7. Streaming SFTP with progress

The Rust reads whole files into memory twice (once to hash, once to upload) and reports
no progress. Worlds are ~5 MB today, but nothing bounds that, and on mobile a 50 MB
world would be a real memory event.

`dartssh2` SFTP exposes streaming read/write, and `crypto` hashes over a stream. Do both
properly and **add an upload/download progress bar** — a visible improvement over the
current app, where "Uploading" is an opaque spinner.

Hash and zip work belongs in `Isolate.run` / `compute` (the Rust equivalent of
`spawn_blocking`, which the current code correctly uses for zip).

---

## 🟢 8. Host key verification (existing security gap)

`check_server_key` returns `Ok(true)` — **any** host key is accepted, so the connection
is trivially MITM-able. Deliberate for LAN, and in-code flagged "revisit before this is
ever exposed off-LAN."

Mobile changes that calculus: phones roam onto untrusted networks, and this app has a
root shell and destructive file operations at the end of the connection.

**Recommendation:** implement TOFU — pin the fingerprint into the profile on first
connect, prompt loudly on change, allow explicit re-pinning. `dartssh2` exposes the host
key for exactly this. Small effort, removes the sharpest edge in the app.

---

## 🟢 9. Pure-Dart SSH performance

`russh` (Rust, `aws-lc-rs`) is faster at crypto than pure Dart. Relevant to bulk SFTP.
`dartssh2` mitigates the worst of it by offloading key exchange to background isolates,
and the workload is a handful of MB over a LAN. Measure before optimising; if transfer
throughput disappoints, the fallback is chunked transfer inside an isolate.

---

## 🟢 10. Smaller ports

| Item | Note |
|---|---|
| **i18n** | ARB + `flutter_localizations` is *better* than i18next here — compile-time-checked getters, no runtime key misses. But it loses the current app's `import.meta.glob` auto-discovery: adding a language becomes "add `app_es.arb`, re-run gen" instead of "drop a file in". Keep `meta.nativeName` self-declaration for the language cycler. ~340 keys to port. |
| **Locale/theme cycling** | `system → en → fr → …` cycle-on-click; trivial with `ThemeMode`/`Locale` + `shared_preferences`. |
| **Command reference** | 484 lines of static Rust data → a Dart const list. Mechanical, but must stay in sync with the real command strings; consider generating both from one source, or a test asserting each documented command matches its builder. |
| **`revealItemInDir`** | No package covers all three desktops; small `Platform.isX` switch over `explorer /select,`, `open -R`, `xdg-open <parent>`. Hidden on mobile. |
| **Clipboard** | Strictly simpler — built-in `Clipboard`, no plugin. |
| **Toasts** | `sonner` → `ScaffoldMessenger`/`SnackBar`, or `another_flushbar` for stacking. Desktop toasts usually want top-right; `SnackBar` is bottom-centre by default, so a small custom overlay may be warranted. |
| **Disclaimer / window size** | `shared_preferences` flag; `window_manager` for size + the minimum the current app lacks. |
| **`savePassword`** | Model + keyring helpers exist but **no UI ever calls them**. Either finish it (a checkbox in the password dialog) or delete it. Don't port dead code. |
| **`file_ops` table** | Written by nothing. Same call: populate it during push/pull, or drop the table. |
| **`greet` command** | Scaffold leftover. Drop. |

---

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Interrupted push leaves server stopped | Medium (mobile) | **Severe** | §2 — resumable envelope + warning |
| Generated SSH key subtly malformed | Medium | High | §1 — round-trip + `ssh-keygen -y` tests |
| Silent empty listings on BusyBox hosts | Low | High | §4 — capability probe |
| Audit db can't evolve / history lost | High over time | Medium | §5 — drift migrations + import |
| Mobile terminal unusable | High if unaddressed | Medium | §6 — accessory bar |
| `xterm` 4.0.0 unmaintained (2 y) | **Materialised** | Medium | Its `TextInput.attach` is incompatible with Flutter 3.44 on desktop — see §6. Worked around with `hardwareKeyboardOnly`. Rendering and escape handling remain sound; expect further API drift, and note a Flutter bump can break input without breaking the build. |
| AGP/plugin churn breaking Android | **Confirmed, already hit twice** | Medium | Pin `path_provider_android`; keep CI building all platforms every commit |
| MITM on untrusted network | Low on LAN | **Severe** | §8 — TOFU pinning |
