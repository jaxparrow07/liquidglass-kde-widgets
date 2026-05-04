This file provides guidance to Agents when working with code in this repository.

## What this repo is

macOS-Tahoe / iOS-style widgets for KDE Plasma 6. Each widget lives under `packages/<name>/` as a standalone KDE Plasma Applet, but all widgets share a common liquid-glass rendering pipeline from `1-common/`.

Requires Plasma 6.x and Qt 6.x. Shader rebuilds need `qsb` from `qt6-base-dev-tools`; scripts use `jq`, `zip`, `kpackagetool6`, `plasmoidviewer`.

## Repo layout & sharing model

- `1-common/components/` — canonical `LiquidGlass.qml`, `MacOSColors.qml`, and `shaders/` directory. **Every package symlinks these in from its own `contents/ui/components/`** (relative paths like `../../../../../1-common/components/LiquidGlass.qml`). Don't copy — always symlink.
- `1-common/fonts/` — shared font files; packages symlink the individual `.ttf`/`.otf` files they need into `contents/fonts/`.
- `packages/<name>/contents/` — the actual plasmoid. Real files here: `main.qml`, `config/`, `widget/` (package-specific QML components), `metadata.json`, `icon.png`. Shared stuff (components, fonts, shaders) is symlinked in.
- `2-packaged/` — `.plasmoid` ZIP outputs (symlinks dereferenced during packaging).

The symlink pattern matters: when you edit `1-common/components/LiquidGlass.qml` or `1-common/components/shaders/liquidglass.frag`, every installed package sees the change after its next reload. Do NOT create per-package copies of these files. Shader `.qsb` files happen to be **hardlinks** to the canonical ones, so `./build-shaders.sh` updates all packages at once.

## Common commands

```bash
./install.sh <name>          # install/update one widget (restarts plasmashell)
./install.sh --all           # install all widgets in packages/
./package.sh <name>          # build 2-packaged/<name>-<version>.plasmoid (symlinks dereferenced)
./package.sh --all
./build-shaders.sh           # recompile 1-common/components/shaders/*.frag -> *.qsb
./test.reload.sh <name>      # open the package in plasmoidviewer (dev iteration; skip plasmashell restart)
```

Notes:
- `install.sh` runs `killall plasmashell && kstart plasmashell` on success; if you're making rapid QML-only changes, `test.reload.sh` is faster.
- `plasmoidviewer` does NOT expose a real containment, so `LiquidGlass`'s wallpaper path fails and the fallback translucent rect is rendered. For end-to-end testing of the glass, install and view on the actual desktop.
- `build-shaders.sh` prefers `qsb6` → `/usr/lib/qt6/bin/qsb` → `qsb`, working around a broken Qt5 `qtchooser` symlink at `/usr/bin/qsb` on some systems.

## LiquidGlass architecture (the key component)

`1-common/components/LiquidGlass.qml` + `1-common/components/shaders/liquidglass.frag` form the backdrop used by every widget. Reading both is essential before touching either.

Pipeline:
1. `ShaderEffectSource { id: wallpaperTex; sourceItem: glass.wallpaperItem }` captures the Plasma wallpaper behind the widget. `wallpaperItem` is discovered by walking `Plasmoid.containment.wallpaperGraphicsObject` via `findRenderableSource()` (follows Loaders and nested children).
2. `ShaderEffect { fragmentShader: "shaders/liquidglass.frag.qsb" }` samples the wallpaper with Snell-on-a-dome edge refraction, chromatic dispersion, tint, corner specular, and a squircle silhouette mask.
3. Fallback `Rectangle` renders a flat tinted rounded rect when `wallpaperItem` is null (panels, plasmoidviewer). `glass.active` toggles between the two.

Important nuances:
- **`realtimeRefraction: false` by default.** `wallpaperTex.live` binds to this. The `updateGeometry()` Timer (16ms) calls `wallpaperTex.scheduleUpdate()` when the widget moves and the width/height Connections do the same on resize — so static wallpapers only re-capture on actual geometry change. Turn the config on only for animated/video wallpapers.
- **Mouse hover state** is plumbed into the shader via `mousePos` (widget UV) and `mouseFade` (0..1 with 180ms Behavior) — currently used by the corner-specular effect only.
- **Shader uniforms** mirror QML properties 1:1 via the `ShaderEffect { property real ...; }` block. Adding a uniform means: add the QML property on `glass`, add it on `glassShader`, add it to the shader's `uniform buf { }`, rebuild shaders.

Shader specifics (`liquidglass.frag`):
- `sceneSDFAndNormal()` returns `vec3(d, nx, ny)` for the squircle silhouette. Fast paths for interior / straight edges skip `pow()`; only corner-wedge fragments pay the p-norm. `d` is normalized by the analytic gradient magnitude to stay unit-gradient at the 45° corner apex (otherwise AA feather and the edge band visibly widen at corners).
- Edge refraction uses `sinθI = (1-t)²` through the `refractThickness` band; normal direction comes directly from `sceneSDFAndNormal` — no finite-difference gradient calls.
- Corner specular: discrete-diagonal pick with a 2-way softmax over the TL+BR vs TR+BL pairs, so only one diagonal's two corners are ever lit. "Light" position is parked at `aTL * 1.2` at rest and blends toward the cursor on hover.

## Per-widget QML conventions

Widgets follow a consistent shape — look at `packages/calendar/contents/ui/main.qml` or `packages/clock-square/contents/ui/main.qml` as templates:

- `PlasmoidItem { Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground; preferredRepresentation: fullRepresentation }` — the glass IS the background.
- `MacOSColors { id: colors; styleMode: plasmoid.configuration.styleMode; appearance: plasmoid.configuration.appearance }` — semantic color/opacity tokens. Use `colors.foreground`, `colors.cardBackground`, etc.; never hardcode colors or branch on `colors.isGlass` / `colors.isLight` inline.
- Standard glass property bindings in every main.qml (cornerRadius, roundnessX10/10, refractThickness, refractIORx100/100, refractScale, tintAlphaPct/100, chromaStrengthPct/100, specStrengthPct/100, realtimeRefraction). Config stores fractional values scaled by 100 (or 10 for roundness) because kcfg entries are Int.
- Plasmoid config lives in `contents/config/main.xml` (kcfg) + `contents/config/config.qml` (ConfigModel) + `contents/ui/config/ConfigGeneral.qml` (Kirigami.FormLayout with `cfg_*` alias properties). The three files must agree entry-by-entry.
- Widget-specific QML components go under `contents/ui/widget/` (e.g. calendar's `TodayBadge.qml`, clock-square's `TickRing.qml` and `DigitalTime.qml`).

## MacOSColors token reference

`1-common/components/MacOSColors.qml` is the single source of truth for all colors and opacities. **Never hardcode a color or branch on `colors.isGlass` / `colors.isLight` in widget code** — add a token here instead.

**Mode axes:**
- `styleMode`: 0 = Glass (translucent shader), 1 = Solid (opaque)
- `appearance`: 0 = Dark, 1 = Light, 2 = Follow system
- `isGlass` / `isSolid` — derived booleans
- `isLight` — **always false in glass mode** (`!isGlass && (appearance===1 || systemLight)`). Glass is always dark-on-dark.

**Core palette (solid mode, adapts light/dark):**
- `background`, `surface`, `surfaceAlt` — fill colors
- `labelPrimary/Secondary/Tertiary/Quaternary` — text hierarchy
- `separator` — divider lines
- `solidBackground`, `solidForeground` — opaque widget bg/fg

**Glass-aware tokens (use these in widgets):**
- `foreground` — white in glass, `solidForeground` in solid
- `glassTint`, `glassFallbackOpacity` — passed directly to `LiquidGlass`
- `todayAccent` — white in glass, red in solid (calendar today badge)
- `punchOutText` — `true` in glass (use destination-out canvas compositing for badge text)

**Card tokens:**
- `cardBackground` — `#ffffff` dark modes, `#000000` light solid
- `cardBackgroundOpacity` — base opacity (0.10 dark, 0.08 light)
- `cardHoverOpacity` — hovered state (0.17 dark, 0.14 light)
- `cardPressOpacity` — pressed state (0.22 dark, 0.20 light)

**Timer action tokens:**
- `countdownText` — white in glass, orange `#FF8B00` in solid
- `actionGreen` / `actionOrange` — icon colors for solid mode buttons
- `actionGreenBg` / `actionOrangeBg` — button background (solid fill in glass, tinted in solid)
- `buttonIcon` — white in glass, `solidForeground` in solid (for cancel/neutral buttons)
- `cancelButtonBg` — semi-white in glass, semi-foreground in solid

## Timer / power conventions

- Do **not** gate plasmoid Timers on `Qt.application.state === Qt.ApplicationActive`. Desktop plasmoids are not a "focused app" — this condition flips to inactive whenever focus moves to another window, freezing the timer. Gate on `visible` if you want to sleep when hidden, or leave `running: true` for always-on clocks/tickers.
- For midnight rollovers etc., prefer scheduling a single-shot Timer at the next boundary over a polling Timer (see `calendar/contents/ui/main.qml`'s `midnightTimer` + `scheduleNextMidnight()`).
- Heavy per-frame work in Canvas `onPaint` should precompute geometry on property changes (see `clock-square/contents/ui/widget/TickRing.qml`'s `_rebuild()` cache of tick endpoints).

## Working with metadata / adding a new widget

1. Copy `packages/calendar/` as a template, rename, edit `metadata.json` (`KPlugin.Id`, `Name`, `Description`, `Version`).
2. Symlink `LiquidGlass.qml`, `MacOSColors.qml`, and the `shaders` directory from `1-common/components/` into `contents/ui/components/` (use relative paths — check an existing package for exact depth).
3. Symlink fonts from `1-common/fonts/` into `contents/fonts/` for each font you actually use.
4. Mirror `contents/config/main.xml` and `contents/ui/config/ConfigGeneral.qml` from an existing package; drop the entries you don't need (e.g. `firstDayOfWeek` is calendar-only).
5. `./install.sh <name>` to register with `kpackagetool6`.

## Compact panel representation

The timer widget has a compact representation for use in Plasma panels. The pattern can be applied to other widgets:

- Set `preferredRepresentation` conditionally: compact in panels, full on desktop:
  ```qml
  preferredRepresentation: (Plasmoid.formFactor === PlasmaCore.Types.Horizontal ||
                            Plasmoid.formFactor === PlasmaCore.Types.Vertical)
                           ? compactRepresentation : fullRepresentation
  ```
- The `compactRepresentation` uses panel-responsive layout `states` (horizontalPanel / verticalPanel / desktop) and a `MouseArea` that toggles `root.expanded`.
- For panel popup context, cap `cornerRadius` to avoid an overly circular popup: `Math.min(plasmoid.configuration.cornerRadius, 20)` when `formFactor` is Horizontal or Vertical.
- Canvas-based indicators inside compact views must bind local mirror properties (e.g. `property real _p: ...`) and call `requestPaint()` in their `onXxxChanged` handlers — Canvas does not auto-repaint on bound property changes.
- Use `TextMetrics` to pre-measure the widest possible label text and pin `width` to that value, so switching label content never causes the compact widget to resize.

## Wide-mode side panel layout

Both the calendar and timer widgets support a side-panel layout when stretched wider than 2:1. The pattern to follow when adding this to a widget:

**Trigger condition:**
```qml
readonly property bool isWide: full.width >= full.height * 2
readonly property real wideGap: Math.round(full.height * 0.04)
```

**Structure:** `LiquidGlass` stays `anchors.fill: parent` (single backdrop for the full widget). The content area splits into two sibling Items:

```
Item { id: leftPanel;  anchors { ...; right: rightPanel.left; rightMargin: wideGap } }
Item { id: rightPanel; width: isWide ? full.height : full.width; anchors.right: parent.right }
```

- `rightPanel` is always the original square content, sized `height × height` in wide mode.
- `leftPanel` is `visible: isWide` and fills the remaining horizontal space.
- Existing content items are reparented into `rightPanel` via `parent: rightPanel` — their internal anchors (`top/left/right/bottom: parent.*`) continue to work unchanged.
- `leftPanel` should have `clip: true` to prevent content overflow.

**Card component pattern (`widget/XxxCard.qml`):**
- Thin cards with compact padding. Height ≈ `fontSize * 2.8`, radius ≈ `height * 0.25`.
- Background: use `colors.cardBackground` (color) + `colors.cardBackgroundOpacity` (real) — automatically resolves to white-on-dark or black-on-light. Pass these as properties; never branch on `isGlass`/`isLight` inside a card component.
- Hover/press opacity: use `colors.cardHoverOpacity` and `colors.cardPressOpacity` tokens.
- Left vertical pill tag (3 px wide, `radius: 1.5`, height = card inner height, colored per entry) for event/category cards. Preset cards omit the pill.
- Font size derived from `full.height`, not width, to stay consistent with the right panel.
- Scrollable lists use `ListView` with `clip: true` and `interactive: true` (default). A `Column + Repeater` is only appropriate for very short fixed lists.

**Left panel sizing constants (scale from `full.height`):**
- `_margin`: `Math.round(full.height * 0.09)` — outer padding matching the right panel's grid margins
- `_cardSize`: `Math.round(full.height * 0.052)` — font size for card text
- `_cardSpacing`: `Math.round(full.height * 0.025)` — gap between cards

**Reference implementations:**
- `packages/calendar/contents/ui/main.qml` + `packages/calendar/contents/ui/widget/EventCard.qml`
- `packages/timer/contents/ui/main.qml` + `packages/timer/contents/ui/widget/PresetCard.qml`

## Calendar event integration

The calendar widget reads live events from KDE's calendar system and groups them into temporal sections in the wide-mode left panel. Events are **never shown in narrow mode** — the left panel is hidden when `width < height * 2`.

### System requirements

- **`plasma-workspace`** — provides `org.kde.plasma.workspace.calendar 2.0` (always present on Plasma 6). The QML module lives at `/usr/lib/x86_64-linux-gnu/qt6/qml/org/kde/plasma/workspace/calendar/`.
- **`kpim6-kdepim-addons`** (optional) — provides the `pimevents` calendar plugin at `/usr/lib/x86_64-linux-gnu/qt6/plugins/plasmacalendarplugins/pimevents.so`. Without it, Akonadi/PIM events are silently skipped and the widget shows "No upcoming events". Install with `sudo apt install kpim6-kdepim-addons`.
- **`kdepim-runtime`** — the Akonadi server that syncs with Nextcloud, Google Calendar, Outlook, etc. via CalDAV/CardDAV. `kpim6-kdepim-addons` depends on it.
- **Holiday and astronomical event plugins** (`holidaysevents.so`, `astronomicalevents.so`) ship with `plasma-workspace` and require no extra packages.
- Calendar sources (CalDAV accounts, local calendars) are configured system-wide in **Merkuro Calendar** or **KOrganizer** — the widget reads whatever Akonadi has already synced.

### Architecture

**Import:** `import org.kde.plasma.workspace.calendar 2.0 as PlasmaCalendar`

**Key types** (from `calendarplugin.qmltypes`):
- `PlasmaCalendar.EventPluginsManager` — loads/unloads calendar plugins. Set `enabledPlugins` to a `QStringList` of plugin IDs. Known IDs: `pimevents`, `holidaysevents`, `astronomicalevents`.
- `PlasmaCalendar.Calendar` — a non-visual backend for a single calendar month. Properties: `days` (7), `weeks` (6), `firstDayOfWeek`, `today`. Methods: `goToYearAndMonth(year, month)` where `month` is **1-based**. The `daysModel` property is a `DaysModel`.
- `DaysModel` (not directly creatable) — call `daysModel.setPluginsManager(manager)` once on `Component.onCompleted`. Then `daysModel.eventsForDate(date)` returns a `QVariantList` of `EventDataDecorator` objects. The `agendaUpdated(date)` signal fires when event data for a date changes.
- `EventDataDecorator` properties: `title` (string), `startDateTime` (QDateTime), `endDateTime` (QDateTime), `isAllDay` (bool), `isMinor` (bool), `eventColor` (string, may be empty), `description` (string), `eventType` (string).

**Multi-month lookahead:** A single `Calendar` backend only holds data for one displayed month. The calendar widget uses **three backends** (current, next, and month-after-next) to cover up to a 90-day lookahead:

```qml
PlasmaCalendar.Calendar { id: calendarBackend; ... Component.onCompleted: daysModel.setPluginsManager(eventPluginsManager) }
PlasmaCalendar.Calendar { id: nextMonthBackend; ... Component.onCompleted: { daysModel.setPluginsManager(eventPluginsManager); goToYearAndMonth(...) } }
PlasmaCalendar.Calendar { id: thirdMonthBackend; ... Component.onCompleted: { daysModel.setPluginsManager(eventPluginsManager); goToYearAndMonth(...) } }
```

Call `goToYearAndMonth(year, 1basedMonth)` — note month is 1-based, opposite of JS `Date.getMonth()`.

**Event collection:** `_doRebuildEventsModel()` iterates dates from today through the lookahead end, calls `daysModel.eventsForDate(date)` on the backend whose displayed month matches the date, deduplicates multi-day events by `title + startDateTime.getTime()`, sorts all-day events before timed events, and groups results into three buckets: today, this week (after today), upcoming (beyond this week).

**Debounce:** Multiple `agendaUpdated` signals fire in rapid succession when plugins load. Use an 80ms debounce Timer to coalesce them before calling `_doRebuildEventsModel()`.

**Section header + card mixed ListView:** The `eventsModel` ListModel holds both section headers (`isHeader: true`) and event entries (`isHeader: false`) interleaved. Use a `Loader` delegate that switches `sourceComponent` based on `model.isHeader`. Pass data to the loaded item via `onLoaded { item.prop = model.value }` rather than `required property` (which doesn't cross the Loader boundary from a delegate context).

### Config entries

Three files must stay in sync (see `contents/config/main.xml`, `contents/ui/config/ConfigGeneral.qml`):

| Entry | Type | Default | Meaning |
|---|---|---|---|
| `eventLookaheadDays` | Int | `2` | Index into `[7, 14, 30, 60]` preset days array |
| `enabledCalendarPlugins` | StringList | `pimevents,holidaysevents` | Plugin IDs to load |

`enabledCalendarPlugins` is a `StringList` kcfg type but QML stores/reads it as a JS array via `plasmoid.configuration.enabledCalendarPlugins`. In `ConfigGeneral.qml` it's bridged with a `cfg_` string property and helper functions that split/join on commas.

### Event colors

`EventDataDecorator.eventColor` is populated from `Akonadi::CollectionColorAttribute` — the per-collection color the user sets in Merkuro or KOrganizer. When it is empty (collection has no color, or event comes from a plugin that doesn't set colors), `_pillColorFor(ev)` falls back to a color keyed on `ev.eventType`:

| `eventType` string | Meaning | Fallback color |
|---|---|---|
| `"Event"` | Calendar event (VEVENT) | `#4B9EFF` blue |
| `"Todo"` | Task / to-do (VTODO) | `#FF9500` orange |
| `"Journal"` | Journal entry (VJOURNAL) | `#34C759` green |
| `"Holiday"` | Public holiday (holidaysevents plugin) | `#FF6B6B` red |

If `eventType` is unrecognised, `colors.accent` (#0a84ff) is used. Collection colors always win over type fallbacks.

### Display rules

- **"Events today"** — `startDate == today`. `timeLabel` = `Qt.formatDateTime(ev.startDateTime, "h:mm AP")` or `"All day"`.
- **"This week"** — after today, before start of next week. `timeLabel` = `Qt.formatDateTime(d, "ddd d")` (e.g. "Wed 7").
- **"Upcoming"** — beyond this week, within lookahead. `timeLabel` = `Qt.formatDateTime(d, "MMM d")` (e.g. "May 15").
- **Empty state** — when `eventsModel.count === 0`, show `"No upcoming events"` centered in `leftPanel` at 45% opacity.
- Section headers that are not the first item get extra `topPadding` to visually separate groups.

### Plugin config pages (collection picker)

The `pimevents` plugin stores which Akonadi collections to monitor in `~/.config/plasmashellrc` under `[PIMEventsPlugin] calendars=<comma-separated collection IDs>`. Without this config, the plugin monitors nothing and returns zero events.

`config.qml` uses the same dynamic `Instantiator` pattern as the Plasma digital clock: it iterates `EventPluginsManager.model`, reads each plugin's `configUi` role (e.g. `"pimevents/PimEventsConfig.qml"`), and appends a `ConfigCategory` tab for each enabled plugin. The pimevents config page shows a tree of Akonadi collections with checkboxes — the user must check the ones they want. Holidays plugin has a similar config page for region selection.

Reference implementation: `KDE/plasma-workspace/applets/digital-clock/config.qml` — the `Instantiator` with `delegate: ConfigCategory` pattern.

## Plan files

Ongoing design decisions for in-progress work may live in `~/.claude/plans/` outside the repo. When resuming work, check there before making architectural assumptions.
