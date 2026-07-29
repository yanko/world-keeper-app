# 05 — Responsive UI (desktop-first, mobile-capable)

Desktop-first is the brief and it matches reality: this is a homelab operator's control
panel, and the primary session is a big window next to a terminal. Mobile is the
"check on it / restart it from the couch" surface. **Design at 1440 px, then prove every
screen at 360 px.** Never the reverse — mobile-first would flatten the information
density the desktop layout depends on.

---

## Breakpoints

Material 3 window size classes, one source of truth:

```dart
enum WindowSize { compact, medium, expanded, large }
// compact  <  600   phone portrait            → bottom NavigationBar
// medium   >= 600   phone landscape / tablet  → collapsed NavigationRail
// expanded >= 1024  small desktop             → extended NavigationRail
// large    >= 1440  desktop                   → extended rail + two-pane content
```

Resolve from `MediaQuery.sizeOf(context).width` (**not** `MediaQuery.of`, which rebuilds
on every metric change including the keyboard). Expose via a small
`WindowSize.of(context)` extension; never scatter magic numbers through widgets.

Set a desktop **minimum window size** of 800×600 via `window_manager` — the current
Tauri app sets none, so it can be dragged to a width where the stepper is unusable.

---

## Navigation shell

Today: a title, a wrapping connection bar, then `Tabs(Server | Audit)` with a nested
`Tabs(Stats | Library | Push | Pull | Terminal)`. Nested tabs are a desktop-web idiom
that translates badly to mobile — flatten it.

**Six destinations, one level:** Stats · Library · Push · Pull · Terminal · Audit.

| Size | Navigation | Connection UI |
|---|---|---|
| compact | bottom `NavigationBar` (Stats/Library/Push/Pull + "More" sheet for Terminal/Audit — Material caps at 5) | compact `AppBar`: profile name + status dot; tap → connection sheet |
| medium | collapsed `NavigationRail` (icons + tooltips) | slim top bar, overflow menu |
| expanded | extended `NavigationRail` (icons + labels) | full connection bar |
| large | extended rail + two-pane where it earns its keep | full connection bar |

`go_router` with a `StatefulShellRoute.indexedStack` — this gives **exactly** the
`keepMounted` behaviour the Terminal tab needs, as a first-class feature rather than the
workaround the current app required (Base UI unmounts inactive panels, which was
destroying live terminal sessions and dropping progress events).

---

## Per-screen behaviour

### The stepper — the signature element, and the hard one

Nine steps (Upload → … → Verify), each a labelled node with a connector. The current
horizontal pipeline is ~700 px minimum. On a 360 px phone that's roughly 40 px per step:
unreadable, and today it just becomes a horizontal scroll, which hides exactly the
information you most want during a destructive remote operation.

**Two layouts, one state model:**

- **expanded / large / medium** — horizontal pipeline as today. Keep the animated fill;
  it is the app's memorable object (SPEC §12).
- **compact** — a **vertical timeline**: node + connector down the left gutter, label
  and live detail to the right. This is strictly better on a phone: every step label is
  fully readable, and the current step's journal line gets real width instead of a
  40-px column.

Auto-scroll the active step into view in both orientations. Respect
`MediaQuery.disableAnimations` (reduced motion) by dropping the spinner to a static
glyph — the current app does this via `motion-safe:` and it must not be lost.

### Audit — tables don't survive contact with a phone

Events (5 cols), SSH commands (4), Errors (3), each with filter dropdowns, a search box,
and two ISO date fields.

- **expanded+** — `DataTable2` / scrollable `Table` as today, click-to-expand rows.
- **compact** — a `ListView` of cards: timestamp + kind + status badge on the first
  line, truncated detail on the second, tap to expand into a full-screen detail page.
  Filters collapse behind a "Filter" button opening a bottom sheet; active filters show
  as `Chip`s.

Keep the 300 ms search debounce and the 200/300-row limits. Add pagination controls at
last — the backend already supports `offset` and the current UI never exposes it.

### Terminal — the biggest mobile gap

`xterm` renders fine on mobile, but a phone has no Esc, Ctrl, Tab, or arrow keys, and
the software keyboard covers half the viewport.

- Wrap in `SafeArea` + resize on `MediaQuery.viewInsetsOf(context).bottom` so the
  keyboard shrinks the terminal instead of covering it.
- **Accessory key bar** above the keyboard on compact: `Esc Tab Ctrl Alt ↑ ↓ ← → ^C`.
  Non-negotiable — without it a mobile shell can't exit `vim` or interrupt a process.
- Default 12 pt on compact, 14 pt desktop; pinch-to-zoom font size.
- Keep the desktop `ResizeObserver` → `resize(cols, rows)` behaviour; in Flutter that's
  a `LayoutBuilder` feeding `terminal.resize()`.

### Stats

- **compact** — single column of stat cards; log tail collapsed behind an expander.
- **medium** — 2-column grid.
- **expanded** — 2-column grid, log tail inline.
- **large** — two-pane: stats left, live log right (promoting the log drawer to a
  permanent panel, which is what you actually want on a big screen).

Use `LayoutBuilder` + `Wrap`/`GridView` with `SliverGridDelegateWithMaxCrossAxisExtent`
(max ~360 px per tile) rather than hard-coded column counts.

### Push / Pull / Library

- File pickers: on compact, "Choose file" only — **`getDirectoryPath` is meaningless on
  mobile** (see [04-TRICKY.md](04-TRICKY.md#3-file-system-idioms-dont-port-to-mobile)).
- Backup list: table on desktop, cards on mobile; the Restore button stays a full-width
  tap target on compact.
- Confirmation dialogs → `AlertDialog` on desktop, full-screen `Dialog.fullscreen` on
  compact so the consequences text is legible.

---

## Design system

Port the tokens rather than reinventing them — they were deliberately chosen (SPEC §12)
and the "one signal colour" discipline is the whole visual thesis.

```dart
// Cool slate/graphite, hue ~250, never pure black.
// Signal = phosphor teal, ONLY for healthy/live/done.
// Destructive red, ONLY for stop/rollback/failure.
const signalLight = Color(0xFF14B8A6);   // ≈ oklch(0.72 0.13 175)
const signalDark  = Color(0xFF2DD4BF);   // ≈ oklch(0.78 0.15 175)
```

Flutter's `ColorScheme` has no "signal" slot, so add a `ThemeExtension`:

```dart
@immutable
class WkColors extends ThemeExtension<WkColors> {
  final Color signal, onSignal, signalContainer;
  ...
}
```

That keeps the constraint enforceable — `Theme.of(context).extension<WkColors>()!.signal`
is a deliberate act, whereas dumping teal into `ColorScheme.primary` would leak it onto
every button and destroy the "signal means live" contract.

Typography: `Geist` for chrome, `GeistMono` for machine data, `JetBrainsMono` for the
terminal. Define `TextTheme` once; add a `.mono` extension for data cells.

---

## Quality floor (SPEC §12's "quality floor", made concrete)

- **Touch targets** ≥ 48×48 dp on compact. Today's `size-7` (28 px) stepper nodes and
  `icon-xs` buttons are mouse-sized and must grow on touch.
- **Text scaling** — honour `MediaQuery.textScalerOf` up to 2.0 without clipping. Test
  the stepper and stat cards at 2.0; that's where fixed-height rows break.
- **Focus** — visible focus rings on every interactive element; full keyboard traversal
  on desktop. Add the shortcuts the current app lacks: `Ctrl/Cmd+R` refresh,
  `Ctrl/Cmd+K` profile switcher, `Esc` to close dialogs.
- **Reduced motion** — `MediaQuery.disableAnimationsOf(context)` gates the stepper
  animation and the pulsing "operation in progress" badge.
- **Screen readers** — `Semantics` on status badges (a coloured dot alone conveys
  nothing); announce step transitions via `SemanticsService.announce` during an
  operation.
- **Contrast** — verify signal-on-background ≥ 4.5:1 in both themes. The teal on light
  is the risky pair.
- **Safe areas** — `SafeArea` everywhere on mobile; notches and home indicators.
- **Long paths** — worlds paths are long and contain spaces. Middle-ellipsis
  (`TextOverflow.ellipsis` loses the filename, which is the useful half) and
  long-press-to-copy on mobile.

---

## Orientation and desktop-window edge cases

- Landscape phone (`medium`) must not show the bottom nav *and* the keyboard — rail wins.
- Support window widths down to 800 px without horizontal scroll on any screen.
- Tablet split-screen lands in `compact`/`medium`; both must be usable.
- Test at 360×640, 768×1024, 1280×800, 1920×1080 — golden tests for the stepper at the
  first and last.
