# TODO

What is left, why it matters, how to build it, and how to know it works.

Everything here is **additive**. The app is feature-complete against the original and has
been verified against real servers on Windows and Android — nothing below is parity work.
See [docs/06 — Build Order](docs/06-BUILD-ORDER.md) for what is already done and why.

Ordered by value, not by size.

---

## 1. Teach the app — a guided demo, not a manual

**The one thing that would most improve this app for someone who is not its author.**

Nothing currently explains what Push does before you press it, and the consequence of
pressing it is that a live game server stops. The About dialog lists every command the app
can run, which answers "what will this do to my box" for someone who reads shell — and
nothing answers "what is this screen for" for anyone else.

### The recommendation: both, and the interactive one is the product

A markdown guide is worth having as a reference, but it is read once and forgotten, and it
cannot show a rollback. **A guided demo against a fake server can**, and that is worth more
here than in most apps precisely because the dangerous actions are the ones that need
explaining. Somebody can press "Stop server & push" and watch the whole nine-state envelope
run, then watch one fail and roll back, with nothing at stake.

### Why this is smaller than it sounds

**The simulation already exists.** `test/support/fake_target.dart` is a complete,
scriptable implementation of `ServerTarget` — 200 lines, with scriptable run states,
per-command responses, injectable failures, and a virtual file listing. It is what the
entire envelope test suite runs against, so every screen in the app already works against
it today. Building demo mode is mostly *promoting that fake out of `test/` and into
`lib/`*, behind a profile that cannot be confused with a real one.

### What to build

1. **`lib/features/demo/demo_target.dart`** — a `ServerTarget` derived from `FakeTarget`,
   with a scripted world set (a couple of slots, a few dated backups) and realistic delays
   so the stepper animates instead of completing instantly.
2. **A demo profile** that appears in the profile dropdown as something unmistakable —
   `Demo server (not a real host)` — and connects instantly with no password and no host
   key prompt.
3. **A permanent banner** while demo mode is active. Not a toast, not a subtitle: a bar
   that does not go away, in a colour used nowhere else.
4. **A coach-mark overlay** walking the destinations in order — Discovery → Stats →
   Library → Push → Pull → Terminal → Audit — with one card per screen explaining what it
   is for and what the buttons do. Skippable, resumable, and offered once on first launch
   right after the safety notice.
5. **Two scripted scenarios**, because the second is the one that builds trust:
   - a push that succeeds end to end;
   - a push that **fails at verification and rolls back**, so the safety story is
     something the user has watched rather than been told.
6. Everything writes to the audit log, so the Audit screen has real rows to explain.
7. **`docs/USER-GUIDE.md`**, generated from the same strings as the coach marks where
   possible, so the written guide cannot drift from the app.

### The risk, and it is the whole design constraint

**A demo target must never be mistakable for a real one, in either direction.** If someone
believes they are in the demo and are not, they stop a real game server. Mitigations, all
required:

- `DemoTarget` is its own type. The connection state should make "connected to a demo" and
  "connected to a host" different states, not a boolean on one state — the same reasoning
  that made `ConnectionStatus` sealed.
- The banner is permanent and unmissable.
- Demo mode is entered only by choosing the demo profile. Never automatically, never as a
  fallback when a connection fails.
- The demo profile cannot be edited into a real one — no host field.
- Audit rows from a demo session are tagged, so the log cannot later be read as evidence
  of something that happened to a server.

### How to test it

- **Unit:** `DemoTarget` satisfies every `ServerTarget` method; a push against it produces
  the full expected state sequence, and the failing scenario produces
  `rollingBack → failed` with the backup restored.
- **Widget:** with the demo profile selected, every destination renders with content rather
  than a "Not connected" placeholder; the coach marks advance and can be skipped; skipping
  is remembered.
- **The safety property, asserted rather than assumed:** a test that walks every
  `ConnectionStatus` a demo session can reach and asserts the banner is present in all of
  them. And the reverse — a real connection never shows it.
- **Manual:** run the walkthrough start to finish on a 360 px phone. The coach marks are
  the most likely thing to overflow, and the accessibility pass found four separate
  overflow bugs in fixed-size chrome.

**Effort:** the largest item here. The demo target is a day; the coach marks and the copy
are the rest.

---

## 2. Real `-f` log streaming

Currently `logTailProvider` re-runs `journalctl -n 300` (or `docker logs --tail`, or
`tail -n`) every two seconds and replaces the whole buffer. It works, and it is visibly a
poll: new lines arrive in batches, and 300 lines cross the wire every tick whether anything
changed or not.

### What to build

A long-lived channel per open log, rather than a repeated command:

- systemd: `journalctl -u <unit> -n 300 -f`
- Docker: `docker logs --tail 300 -f <container>`
- process: `tail -n 300 -f <path>`

`SshSession` already opens PTY channels for the Terminal, so the transport for this exists.
The work is a `Stream<String>` provider that owns a channel, appends lines as they arrive,
and — the part that actually needs care — **tears the channel down reliably**. A leaked
follow channel is an open SSH channel per log the user ever opened.

### Watch out for

- **Disconnect and reconnect.** The stream must close when the connection drops and not
  resurrect against a dead session.
- **The operation window.** A push stops the service; `journalctl -f` survives that,
  `tail -f` on a file that gets replaced does not. `tail -F` (capital) follows by name and
  handles the file being recreated — which is exactly what a world swap does to a log.
- **Bounded buffer.** A server that logs continuously must not grow the buffer without
  limit. Cap it and drop from the front.

### How to test it

- **Unit:** a fake transport that emits lines on a schedule; assert the buffer grows,
  stays capped, and that closing the provider closes the channel.
- **The leak, explicitly:** open and close the log panel fifty times and assert the number
  of channels the transport was asked to open equals the number closed. This is the failure
  that only shows up after an hour of use.
- **Live:** against a real server, with `WK_LIVE_PROFILE` set — start a follow, run a push,
  confirm the stream survives the service restart and keeps producing lines.

**Effort:** half a day, most of it lifecycle.

---

## 3. "This host does not run Core Keeper"

Connecting to the wrong IP currently produces "Service — nothing auto-detected" and
"Worlds path — none found", both of which are true and neither of which says the obvious
thing. This cost a real debugging session: a wrong IP in a profile looked exactly like a
broken probe.

### What to build

When the probe finds **no service of any kind and no worlds anywhere**, say so directly
above the manual fields: *this host does not appear to be running Core Keeper — check the
address, or enter the details by hand if it is installed but not running.* Keep the manual
fields, since a stopped, unusual install is a real case.

The condition already exists as `DiscoveryResult.foundNothing`; it is simply not surfaced.

### How to test it

- **Unit:** `foundNothing` is true for an empty host and false when either a service or a
  worlds path was found.
- **Widget:** the banner appears for an empty probe result and does not appear when a
  service was found but the worlds path was not — that second case is the LXC that started
  all this, and it must not be told it has no Core Keeper.

**Effort:** an hour.

---

## 4. Offer to reconnect after a background drop

Android freezes a backgrounded process and takes its sockets with it. The app now notices
on resume and says so, which was the important half. It does not offer to reconnect.

This was deliberate at the time: a password profile has nothing to reconnect *with*. **Key
auth changes that** — a key profile can reconnect silently and correctly.

### What to build

On a background drop, if the profile uses key auth, offer a "Reconnect" action on the
disconnected state. Not automatic: a silent reconnect re-runs the host-key check with
nobody watching, and a changed host key is the one prompt that must never resolve itself.

### How to test it

- **Unit:** the action is offered for a key profile and not for a password profile.
- **Widget:** tapping it calls `connect` with the same profile.
- **The security property:** a reconnect with a *changed* host key still raises the prompt
  and still refuses without an explicit yes.

**Effort:** two hours.

---

## 5. Steam build-id badge

A SPEC §10 stretch goal, never built in either app. Reads the installed Core Keeper build
id from the server and shows it on Stats, so "the server updated and my world broke" has a
number attached to it.

### What to build

Read `steamapps/appmanifest_1963720.acf` from the server's install directory and parse
`buildid`. The install directory is not currently discovered — it can be derived from the
launch script's directory, which the probe already captures.

### How to test it

- **Unit:** the ACF parser against a real manifest fixture, including a missing file and a
  malformed one. It is a bespoke key-value format, not JSON.
- **Widget:** the badge shows the id when present and is simply absent when not — an empty
  "build id: —" tile is noise on a screen that is mostly numbers.

**Effort:** half a day, most of it discovery of the install path.

---

## 6. Platforms that build but are unverified

macOS, Linux and iOS runners exist in the tree and have launcher icons generated, and none
has ever been built or run. Windows and Android are the verified targets.

Before claiming any of them: build it, connect to a real server, run a pull. The Android
`INTERNET` permission bug is the precedent — a release build that fails at `connect()`
while every debug build works, invisible to the entire test suite.

---

## Not doing, and why

- **Resuming an interrupted operation automatically.** The app now detects one and offers
  to start the service. Re-running a half-finished swap without knowing which half finished
  is how a world gets overwritten with a partial copy; a restore from the Library is the
  correct recovery and has its own confirmations.
- **Saved passwords.** `SecretsRepository` was deleted in favour of key auth, which is
  per-host, revocable from the server side, and never puts the secret anywhere. The
  `savePassword` field stays on the model only because `config.json` is shared with the
  Tauri build and must round-trip.
- **Localising the audit log.** Event kinds, SSH commands and remote stderr stay English in
  every language. That log is evidence, it gets exported, and rows that change wording
  depending on who ran the app cannot be compared. See the note at the top of
  [lib/l10n/l10n.dart](lib/l10n/l10n.dart).
