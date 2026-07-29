# 01 — Feature Inventory (what exists today)

Exhaustive catalogue of the current Tauri app's behaviour, read out of the source
(`src-tauri/src/*.rs`, `src/**/*.tsx`), not out of SPEC.md — the spec describes intent,
this describes what actually shipped. Every row is something the Flutter rewrite has to
reproduce or consciously drop.

Source-of-truth line counts: ~4,700 lines of Rust across 19 modules, ~3,300 lines of
TypeScript/TSX across 24 files, 340 keys × 2 locales.

---

## 1. Architecture as built

```
React/TS frontend  ──invoke()──▶  36 Tauri commands  ──▶  Rust modules
      ▲                                                     │
      └────────── Tauri events ◀────────────────────────────┘
        push-progress / pull-progress / restore-progress
        terminal-output / terminal-closed
```

**Single global app state** (`state.rs::AppState`), created once at startup:

| Field | Type | Purpose |
|---|---|---|
| `audit` | `AuditDb` (sqlx pool) | Cloneable handle to the SQLite audit db |
| `session_id` | `i64` | The `sessions` row for this app run; immutable |
| `connection` | `Mutex<Option<Connection>>` | The one active SSH connection |
| `terminal` | `Mutex<Option<TerminalSession>>` | The one PTY session |
| `operation_lock` | `Mutex<()>` | Mutual exclusion for push/pull/restore/disconnect **only** |

`Connection` is a two-state enum: `Raw` (authenticated, `ServiceKind` unknown) →
`Target` (discovery confirmed, wrapped in `SshTarget`).

### The concurrency model (important, and easy to get wrong)

- `SshSession` holds `Arc<Handle<Client>>` and is **cheap to clone** — clones share one
  multiplexed SSH connection, opening independent channels.
- Command handlers call `clone_target()`, which takes the `connection` lock *briefly*,
  clones out, and drops the lock. They never hold it for the operation's duration.
- Result: stats polling, the log drawer, and the Terminal all keep working **during** a
  running push. Only push/pull/restore/disconnect contend, and they contend on the
  separate `operation_lock` via `try_lock` (failure → the string `"another operation is
  already in progress"`).
- The frontend mirrors this with `OperationsProvider.activeOperation` as a friendly
  first line of defence; the backend lock is the real one.

---

## 2. The `ServerTarget` seam

One trait (`target.rs`), one implementation (`ssh::SshTarget`). All systemd/Docker/
process branching lives inside that impl; the push/pull/restore state machines are
written purely against the trait and know nothing about the target kind.

```rust
trait ServerTarget {
    async fn exec(&self, cmd: &str) -> Result<ExecOutput>;
    async fn push_file(&self, local: &Path, remote: &str) -> Result<u64>;
    async fn pull_file(&self, remote: &str, local: &Path) -> Result<u64>;
    async fn stat(&self, dir: &str, glob: &str) -> Result<Vec<FileEntry>>;
    async fn logs_tail(&self, lines: u32) -> Result<String>;
    async fn service_control(&self, action: ServiceAction) -> Result<ExecOutput>;
    async fn status(&self) -> Result<RunState>;
    async fn active_since(&self) -> Result<Option<String>>;
    async fn udp_listening(&self) -> Result<Vec<String>>;
    async fn fix_perms(&self, path: &str) -> Result<()>;
    fn worlds_path(&self) -> &str;
    fn service_kind(&self) -> &ServiceKind;
}
```

`RunState` (`Running | Stopped | Failed | Unknown`) is the normalisation that keeps the
state machine agnostic — systemd says `active`/`inactive`/`failed`, Docker says
`running`/`exited`/`created`/`dead`/`paused`, Process just has pgrep output.

### Per-ServiceKind command matrix (exact strings, all `shq()`-quoted)

| Operation | Systemd | Docker | Process |
|---|---|---|---|
| status (raw) | `systemctl is-active <unit>` | `docker inspect -f {{.State.Status}} <c>` | `pgrep -af <start_cmd>` |
| status (normalised) | same, mapped | same, mapped | `pgrep -f <start_cmd>`, empty ⇒ Stopped |
| stop | `systemctl stop <unit>` | `docker stop <c>` | `<stop_cmd>` verbatim |
| start | `systemctl start <unit>` | `docker start <c>` | `<start_cmd>` verbatim |
| logs tail | `journalctl -u <unit> -n N --no-pager` | `docker logs --tail N <c>` | `tail -n N <log_path>` (errors if no path) |
| active since | `systemctl show -p ActiveEnterTimestamp --value <unit>` | `docker inspect -f {{.State.StartedAt}} <c>` | `None` |
| fix perms | `chown -R <user>:<user> <path>` (only if steamUser set) | no-op | no-op |
| stat/glob | `find <dir> -maxdepth 1 -name <glob> -printf '%s %T@ %p\n' 2>/dev/null` | same | same |

### `udp_listening` — the four-tier Docker fallback

Genuinely subtle; reproduce faithfully.

1. **Systemd/Process:** `ss -ulnp 2>/dev/null | grep -i corekeeper`.
2. **Docker tier 1:** the same host-side `ss` grep first — under `--network host` the
   process is in the host netns and shows up by name. Confirmed on a real deployment.
3. **Docker tier 2:** bridge networking → host only sees `docker-proxy`. Resolve
   published ports with `docker port <c> | grep -i udp`, parse the host port after
   `->` and after the last `:`, then `ss -uln | grep -E ':(p1|p2)\b'`.
4. **Docker tier 3:** `docker exec <c> ss -uln`. Guarded by `out.success()` because
   some OCI runtimes print "exec failed" to *stdout*, which would otherwise be
   mistaken for listener data.
5. **Docker tier 4:** `docker exec <c> sh -c 'cat /proc/net/udp /proc/net/udp6'` —
   `ss` is often missing from minimal images, `cat`/`sh` are not. Checks v6 too because
   .NET/Unity commonly binds dual-stack. Filters the `sl` header line. Any bound UDP
   socket counts (Core Keeper binds an **ephemeral** port — confirmed 56967, *not* the
   commonly-assumed 27015).

---

## 3. Connection profiles & auth

**Storage:** `tauri-plugin-store` JSON at `%APPDATA%/com.civortech.worldkeeper/config.json`.

```jsonc
{ "profiles": [ { "id", "name", "host", "port"(=22), "user", "auth": "key"|"password",
                  "keyPath"?, "savePassword", "discovered"? } ],
  "worldDetection": { "patterns": ["*.world.gzip"] },
  "activeProfileId": string|null }
```

`discovered` = `{ os, serviceKind, worldsPath, steamUser, launchScript, probedAt }`.

**Secrets:** `keyring` crate, service `com.civortech.worldkeeper`, username = profile id.
Never in the JSON. Commands: `save_password` / `has_saved_password` /
`delete_saved_password`.

**Behavioural details:**
- Password auth prompts per connect (a dialog with Enter-to-submit). Note: `savePassword`
  exists in the model and keyring helpers exist, but the ConnectionBar **never calls
  them** — there is no "save password" checkbox in the UI today. The saved-password path
  is dead code end to end.
- Key auth reads an OpenSSH private key from `keyPath`, uses
  `best_supported_rsa_hash()` for RSA hash negotiation.
- **Host keys are not verified at all** (`check_server_key` returns `Ok(true)`).
  Deliberate for LAN/homelab; flagged in-code as "revisit before off-LAN".
- Profile dropdown, New/Edit/Delete buttons all disabled unless `status ==
  "disconnected"`. Edit preserves fields the form doesn't show (auth/keyPath/
  savePassword/discovered) by spreading the original object.
- Delete confirms, and drops `discovered` silently along with the profile; keyring
  entries are deliberately left alone.

### `setup_key_auth` (one-time helper)

Requires an existing connection. Runs `ssh-keygen -t ed25519 -f <appdata>/keys/
<profileId>_ed25519 -N "" -C world-keeper -q` **as a subprocess**, refuses if the file
already exists, then appends the pubkey to the remote `~/.ssh/authorized_keys`
idempotently:

```sh
mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && \
chmod 600 ~/.ssh/authorized_keys && \
(grep -qF '<key>' ~/.ssh/authorized_keys || echo '<key>' >> ~/.ssh/authorized_keys)
```

Then rewrites the profile to `auth=key`, `keyPath=<generated>`, `savePassword=false`.

---

## 4. Discovery probe

Read-only, never auto-applied — always shown for confirmation (`DiscoveryConfirm`).
Runs against the raw `SshSession`, since its whole job is to *determine* the ServiceKind.

**Step A — OS:** `cat /etc/os-release`, take `PRETTY_NAME=`, strip quotes. Informational.

**Step B — ServiceKind**, in order, first hit wins:

1. `systemctl list-units --type=service 2>/dev/null | grep -i core` → take first
   whitespace token, strip `.service`.
2. `docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | grep -i core`.
3. `pgrep -af _launch.sh 2>/dev/null || pgrep -af CoreKeeperServer 2>/dev/null` →
   strip the leading pid, `start_cmd` = the cmdline, `stop_cmd` = `pkill -f <cmdline>`,
   `log_path` = None.

**Ambiguity handling:** exactly 1 hit → auto-select. >1 → return **candidates**, select
nothing, make the user pick. Candidates are sorted by `specificity_rank()`:
alphanumeric-only lowercase compare, `corekeeper` = 0, starts/ends-with = 1, else 2 — so
`corekeeper` sorts above `corekeeper-api`. Ranking only *orders*, never auto-picks.

For systemd candidates it additionally runs
`systemctl cat <unit> | grep -iE 'ExecStart=|User=|WorkingDirectory='` to populate
`execStart` / `workingDirectory` / `steamUser`.

**Step C — worlds path:**
- Non-Docker: `find /home -name '*.world.gzip' 2>/dev/null`.
- Docker: `docker inspect <c> --format '{{json .Mounts}}'` (**the format string must be
  shell-quoted** — it contains a space and word-splits otherwise; this was a real bug),
  take every `Mounts[].Source` (bind *and* named volume alike — both are real host
  dirs), and `find <source> -name '*.world.gzip'` inside each.
- Both funnel into `dedupe_parent_dirs()`: parent dir of each match, sorted, deduped →
  0 ⇒ manual entry, 1 ⇒ confident, >1 ⇒ candidate list.

**Confirmation UI** lets the user override the service (dropdown of candidates, or a
free-text systemd unit box when nothing was found) and the worlds path (dropdown or
free text), plus a Re-scan button. Only on confirm is `profile.discovered` written and
the live connection upgraded `Raw → Target`.

---

## 5. Push — the safe swap envelope

Emits `push-progress`; each transition also writes a `state_enter` audit row.

```
Uploading → CheckingService → Stopping → BackingUp → Copying → FixingPerms
  → Starting → CapturingGameId → Verifying → Done
                      ↓ any failure
              RollingBack → Failed
```

1. **Uploading** — `mkdir -p <worlds>/.staging`, then SFTP the main file to
   `<staging>/<slot>.world.gzip` (**always canonicalised to the slot name regardless of
   the source filename**) and the pugbackup to `<slot>.world.gzip.pugbackup` if present.
   Each upload is verified: local SHA-256 (whole file read into memory) vs. remote
   `sha256sum`. Empty remote hash or mismatch ⇒ bail.
2. **CheckingService** — records `prior_state`; audit-only, not branched on.
3. **Stopping** — `stop_and_wait`: issue stop, then poll `status()` every **1.5 s** up
   to **30 s** for `Stopped`.
4. **BackingUp** — stat **exactly two filenames** (`<slot>.world.gzip` and
   `<slot>.world.gzip.pugbackup`), *not* a `<slot>.world.gzip*` glob. If neither exists
   → `None` (first push to this slot), which is not a failure. Else `mkdir -p
   <worlds>/.backups/<slot>.<UTC %Y-%m-%d_%H%M%S>` and `cp -a` each in. Records a
   `backups` row with the summed byte count.
   > The exact-pair rule matters: `ich777/steamcmd:corekeeper` keeps `.old`/`.old2`/
   > `.backup` snapshots and users keep manual ones, all sharing the slot prefix. A glob
   > swept them into backups and let a restore overwrite unrelated files.
5. **Copying** — `mv` staged → live. Pugbackup only moved if the source had one;
   otherwise the existing one is left alone (already preserved in the backup, and Core
   Keeper regenerates it).
6. **FixingPerms** — `target.fix_perms(worlds_path)`.
7. **Starting** — `start_and_wait`, same 1.5 s / 30 s poll for `Running`. If status goes
   `Failed` while waiting for `Running`, bail early with a 50-line log tail.
8. **CapturingGameId** — poll `logs_tail(200)` every 1.5 s up to **90 s**, `find_game_id`.
   Returns `Option` — a miss is *not* a failure.
9. **Verifying** — `wait_for_udp_listening` (poll to **90 s**) **and** `status() ==
   Running`. Either false ⇒ bail ⇒ rollback.
10. **Done** → `PushResult { slot, gameId, bytesUploaded, backupPath, udpListening }`.

**Rollback** (best-effort, never itself fails, returns a note string for the audit log):
`cp -a <backup>/. <worlds>/` → `fix_perms` → **always** attempt
`service_control(Start)`. If no backup existed, notes "no backup existed to restore" and
still attempts the restart.

> The 90 s timeouts were raised from 30 s: Docker reports "running" as soon as the
> entrypoint is alive, long before Core Keeper has loaded a world and bound its port,
> so verification was failing on servers that were merely still starting.

---

## 6. Pull

Deliberately shorter — nothing on the server is modified, so no backup/perms/rollback.

```
CheckingService → Stopping → Downloading → Starting → Done   (Failed on error)
```

- `list_remote_worlds`: `stat(worlds, "*.world.gzip")`, parse filenames, **exclude
  pugbackups** (a bare pugbackup is not offerable as "world N"), sort by slot.
- Download uses the glob `<slot>.world.gzip*` (deliberately *inclusive* here, unlike
  backup) into `%TEMP%/ckm-pull-<nanos>/`.
- **The restart is issued regardless of whether the download succeeded.** If both fail,
  the download error is annotated with the restart failure and the download error wins.
- Packaging is a **separate command** (`package_pulled_world`) run after the server is
  already back up — folder (copy both files, canonically renamed) or zip (`zip` crate,
  on `spawn_blocking`). The temp dir is deleted afterwards either way, success or not.

---

## 7. Restore (World Library)

Push's envelope minus Upload — the source is already on the remote host.

```
CheckingService → Stopping → BackingUp → Copying → FixingPerms
  → Starting → CapturingGameId → Verifying → Done  /  RollingBack → Failed
```

- **Path containment guard:** refuses if `!source_backup_path.starts_with(worlds_path)`,
  *before* stopping anything — defends against a stale list pointing at another host.
- Backs up what's currently live first (reusing `push::back_up`), noted
  `"pre-restore safety backup"` — so a bad restore is itself undoable.
- `copy_backup_into_place` cherry-picks **exactly** `<slot>.world.gzip` (+ `.pugbackup`
  if present) out of the backup dir, ignoring anything else in there. Missing main file
  ⇒ bail. Copies, doesn't move — the backup dir stays intact.
- Reuses `push::rollback`, `capture_game_id`, `wait_for_udp_listening`.

### Backup listing — reads the server, not the database

`list_remote_backups` runs `stat(<worlds>/.backups, "*")`, skipping the directory itself
(because `find -maxdepth 1 -name '*'` matches depth 0 too), derives `slot` from the
leading `N.` of each name, and sums each backup's contents with a second `stat`. Sorted
newest-first, which works because `<slot>.YYYY-MM-DD_HHMMSS` sorts lexicographically =
chronologically.

The audit db is consulted **only to enrich** — `note`/`gameIdBefore` are attached when a
row's `lxc_path` matches, and the db rows are scoped to the connected host. A real
backup with no db record still lists.

> This was a bug fix: the list used to come *from* the db, so "Clear audit log" silently
> made real, restorable backups invisible.

---

## 8. Stats dashboard

Polled every **5 s** from `StatsPanel`, plus manual Refresh. Guarded by a
`requestIdRef` monotonic counter so a slow earlier response can't overwrite a fresher
one (`collect()` is several sequential round-trips and Docker's `udp_listening` can be
slow).

`collect()` gathers, per poll: service status (raw text), `active_since`, server clock
(`date -u +%Y-%m-%dT%H:%M:%SZ`), `udp_listening`, `/proc/meminfo` (MemTotal +
MemAvailable), `df -h --output=size,used,avail,pcent <worlds> | tail -n 1`,
`/proc/uptime`, and `logs_tail(200)` → `find_game_id`.

**`find_game_id`** scans lines **in reverse** (last match wins, so a stale line from a
previous run never beats the fresh one) for these markers:

```
"GameID:"  |  "Started session with info:"  |  "Server Game ID:"
```

Three variants from three different packagings. `GameID path: ...` deliberately does not
match (no colon immediately after `GameID`). Expect to keep adding markers.

Display: status badge (signal colour when `active`), since/uptime/server-clock line,
current world + copy-to-clipboard button, memory used/total, disk used/total/percent,
UDP listening lines in a `<pre>`, and the recent log tail. Also shows a live banner with
the current step of any running push/pull/restore.

**Log drawer:** separate dialog, polls `get_log_tail(300)` every **2 s** (deliberately
polling, not a true `-f` stream). Auto-scrolls only when already within 80 px of the
bottom.

---

## 9. Terminal

Real PTY over the same authenticated connection, on its own channel.

- `channel.request_pty(true, "xterm-256color", 80, 24, 0, 0, &[])` then `request_shell`.
- Channel `split()` into read/write halves. A background task loops the read half and
  emits `terminal-output` per chunk; on `Close`/`Eof`/`ExitStatus`/`None` it breaks and
  emits `terminal-closed`.
- `terminal_write` (keystrokes) and `terminal_resize` (`window_change`) go to the write
  half independently — concurrent with normal `exec()` traffic.
- One session at a time; opening again replaces and closes the old one. Disconnect tears
  it down. **Manual start only** — never auto-opened, because it's a real unsandboxed
  shell as whatever user the profile connects as.
- Frontend: xterm.js + FitAddon, JetBrains Mono, `ResizeObserver` → `fit()` +
  `terminal_resize`. Transparent background. The tab is rendered with `keepMounted` so
  tab switches don't destroy the session (Base UI unmounts inactive panels by default).

---

## 10. Audit log

SQLite at `<appdata>/ckmanager.db` via `sqlx`, own pool (not through
`tauri-plugin-sql`, whose commands are only reachable from JS).

Six tables: `sessions`, `events`, `file_ops`, `backups`, `ssh_commands`, `errors`.
Schema is `CREATE TABLE IF NOT EXISTS` — **no migration mechanism at all.**

- **Every** `SshSession::exec` is logged to `ssh_commands` (command, exit code, stdout,
  stderr, duration ms) — one choke point catches all remote traffic. stdout/stderr are
  truncated at **4000 bytes** with a char-boundary backoff, else a 1.5 s `journalctl
  -n 200` poll would bloat the db unboundedly.
- `events` gets `app_start`, `connect`, `disconnect`, `discover`, `discover_confirmed`,
  `key_auth_setup`, `push_begin`/`push_done`, `pull_begin`/`pull_done`,
  `restore_begin`/`restore_done`, `state_enter` (one per transition), `error`,
  `audit_cleared`.
- `errors` is a separate scannable list keyed by `context` (`connect`, `discovery`,
  `push`, `pull`, `restore`, `ssh_exec`).
- `file_ops` and `log_file_op` exist but are **never called** — dead code.
- Reads are typed Rust (`sqlx::QueryBuilder`, parameterised), never raw SQL from JS.
  Filters: kind, session, ok, free-text LIKE over several columns, ISO date range,
  limit (default 200, clamped 1–1000) + offset, `ORDER BY id DESC`.

**UI:** three sub-tabs (Events / SSH commands / Errors), each with filter dropdowns, a
debounced (300 ms) search box, a results table, and click-to-expand rows showing full
`detail_json` / stdout+stderr.

**Clear log:** two sequential confirmation dialogs (the second one is comedic but
deliberate), deletes everything except the *current* session row — because
`AppState.session_id` is an immutable `i64` that would otherwise dangle — then logs its
own `audit_cleared` event.

**Export:** zip containing `events.csv`, `ssh_commands.csv`, `errors.csv` and a raw copy
of `ckmanager.db`, via a native save-as dialog.

---

## 11. Chrome & smaller features

- **About dialog** — version, and the resolved on-disk paths for config / audit db /
  generated keys, each with a "show in folder" button (`revealItemInDir`). Plus the
  **command reference**: a static, grouped catalogue (`command_reference.rs`, 484 lines)
  of every remote command the app can issue, with real discovered values substituted in
  where known and `<placeholders>` otherwise, filtered to just the connected
  ServiceKind. Per-command copy + "copy all" as plain text.
- **Disclaimer dialog** — shown once, gated on `localStorage["ckm.disclaimer-
  acknowledged.v1"]`; the `.v1` suffix is meant to be bumped if the warning changes
  materially.
- **Theme toggle** — cycles system → light → dark (`next-themes`), with a `mounted`
  guard against a first-paint flash.
- **Language toggle** — cycles system → each installed locale. Locales are
  **auto-discovered** via `import.meta.glob("../locales/*.json")`; each file self-declares
  `meta.nativeName`, read via `getResource` so a language's name always shows in itself.
  Persisted in `localStorage`. `i18next.d.ts` types keys against `en.json` so a typo is a
  compile error.
- **Toasts** — `sonner`, used for essentially every success/failure.
- **Design tokens** — cool slate/graphite base (hue 250, faint blue tint, never pure
  black), one "signal" colour (phosphor teal, `oklch(0.72 0.13 175)` light /
  `0.78 0.15 175` dark) used *only* for healthy/live/done, destructive red reserved for
  stop/rollback/failure. Geist (UI) + Geist Mono (machine data) + JetBrains Mono
  (terminal), all bundled via fontsource.
- **Window** — 1920×1080 default, no min size set.

### Deliberately not implemented
- Steam build-id "update available" badge (SPEC §10 stretch).
- True `-f` log streaming (polling instead).
- The `greet` scaffold command still registered.
- `savePassword` UI (see §3).
- `file_ops` table writes.

---

## 12. Behavioural details worth not losing

These are the ones a from-scratch rewrite silently gets wrong.

1. `shq()` single-quote escaping on **every** interpolated value — real paths contain
   spaces (`.../Pugstorm/Core Keeper/DedicatedServer/worlds`).
2. Upload always renames to `<slot>.world.gzip` regardless of source filename.
3. Backup/restore name exact files; pull download uses a glob. The asymmetry is intended.
4. `find_game_id` scans in **reverse**.
5. `list_remote_backups` must skip the `.backups` dir itself.
6. Pull restarts the service even when the download failed.
7. Discovery never auto-applies; ranking only orders.
8. Clear-audit-log must preserve the current session row.
9. Stats polling needs the stale-response guard.
10. Local world files are recognised **by filename only** — a content check was tried
    and reverted: despite the `.gzip` extension these files are *not* gzip (`gzip -t`
    rejects a real `0.world.gzip`; the magic bytes aren't `1F 8B`). Any file whose name
    merely *contains* `.world.gzip` is accepted, with `slotInferred: false` and slot
    defaulting to 0 for the user to override.
11. Zip inputs are extracted to `%TEMP%/ckm-extract-<nanos>` and scanned recursively.
12. Picking a single strictly-named world file scans its **whole parent directory**, so
    the sibling pugbackup is picked up too.
