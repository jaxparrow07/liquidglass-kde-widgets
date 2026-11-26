# Design Guidelines

How widgets in this repo should look and behave. Read this before designing a new widget,
proposing one, or changing anything visual. For code structure and the rendering pipeline, see
[AGENTS.md](AGENTS.md).

## Design target

Every widget is a recreation of a **macOS Tahoe / iOS widget**, not a new design that borrows the
style. When in doubt, match Apple's version: layout, hierarchy, type, spacing and motion.

- Each widget should map to a widget or system surface that exists on macOS / iOS (Clock, World
  Clock, Weather, Calendar, Music / Now Playing, Timer, …). A widget with no macOS counterpart
  needs a strong reason to be in this repo (see [CONTRIBUTING.md](CONTRIBUTING.md#building-a-new-widget)).
- Content first: one glanceable purpose per widget. No settings, toolbars or dense controls on the
  face of the widget; configuration lives in the config dialog.
- The glass **is** the background. Widgets set `Plasmoid.backgroundHints: NoBackground` and draw a
  single `LiquidGlass` that fills the widget. Don't stack extra opaque panels on top of it.

## Style modes

Every widget must look right in all of these combinations, which the user picks in Appearance:

| `styleMode` | `appearance` | Result |
|---|---|---|
| 0 Glass | 0 Dark | Dark-tinted glass, white content (the default look) |
| 0 Glass | 1 Light | Light-tinted glass, dark content |
| 1 Solid | 0 Dark | Opaque dark background, white content |
| 1 Solid | 1 Light | Opaque light background, dark content |
| either | 2 Follow system | Resolves to Dark or Light from the Plasma color scheme |

Screenshot all of them before opening a PR. The fallback path (flat tinted rectangle used in
panels and `plasmoidviewer`) must also stay legible.

## Color tokens

`1-common/components/MacOSColors.qml` is the **single source of truth** for every color and
opacity. Widgets create one instance and read from it:

```qml
MacOSColors {
    id: colors
    styleMode: plasmoid.configuration.styleMode
    appearance: plasmoid.configuration.appearance
}
```

Rules:
- **Never hardcode a color** in widget code, and never branch on `colors.isGlass` /
  `colors.isLight` / `colors.glassIsLight` inline to pick one. If you need a color that doesn't
  exist, add a semantic token to `MacOSColors.qml` and resolve the mode logic there.
- Name tokens by role (`cardBackground`, `countdownText`), not by value (`white50`).

### Mode axes
- `styleMode`: 0 = Glass (translucent shader), 1 = Solid (opaque).
- `appearance`: 0 = Dark, 1 = Light, 2 = Follow system.
- `isGlass` / `isSolid`: derived booleans.
- `isLight`: light **solid** mode only. It is always false in glass mode.
- `glassIsLight`: light **glass** mode (Glass + Light, or Glass + Follow system on a light
  scheme). Kept as a separate axis so older `isGlass ? a : b` code keeps its dark-glass look.
  Only tokens read it.
- `effectiveLight`: whether content should be dark (light mode in either style).

### Core palette (solid mode, adapts light/dark)
- `background`, `surface`, `surfaceAlt`: fill colors.
- `labelPrimary` / `labelSecondary` / `labelTertiary` / `labelQuaternary`: text hierarchy.
- `separator`: divider lines.
- `solidBackground`, `solidForeground`: opaque widget background / foreground.
- `accent` (`#0a84ff`), `accentRed`: system accents.

### Glass-aware tokens (use these in widgets)
- `foreground`: main content color. White on dark glass, near-black on light glass, and
  `solidForeground` in solid.
- `glassTint`, `glassTintAlpha`, `glassFallbackOpacity`: passed straight to `LiquidGlass`.
- `todayAccent`: white on dark glass, red otherwise (calendar today badge).
- `punchOutText`: `true` in glass. Badge text is cut out with destination-out compositing
  instead of drawn.
- `musicSecondary`: secondary text in the music widget.
- `weather*` tokens: weather widget gradients, separators, range bar and icon set.
- `photoSaturation`, `photoOpacity`: photo rendering in the photos widget. Full color and
  opaque in solid; monochrome (-1) at 0.75 opacity in glass, so the glass shows through.
- `photos*` tokens: the photos widget empty state (black card, app tile colors, monochrome
  flower in glass, placeholder text opacity).

### Card tokens
- `cardBackground`: white on dark modes, black on light modes (light solid or light glass).
- `cardBackgroundOpacity`: resting opacity (0.10 dark, 0.08 light).
- `cardHoverOpacity`: hovered (0.17 dark, 0.14 light).
- `cardPressOpacity`: pressed (0.22 dark, 0.20 light).

### Action tokens (timer and similar buttons)
- `countdownText`: white on dark glass, orange `#FF8B00` otherwise.
- `actionGreen` / `actionOrange`: icon colors for solid-mode buttons.
- `actionGreenBg` / `actionOrangeBg`: button background (solid fill in glass, tinted in solid).
- `buttonIcon`: neutral/cancel button icon color.
- `cancelButtonBg`: neutral/cancel button background.

## Typography

- Use the bundled fonts in `1-common/fonts/`, symlinked into each package's `contents/fonts/`
  (only the files that package uses):
  - **SF Pro Display** (Regular / Light / Thin): default UI and large numerals.
  - **SF Pro Rounded**: analog and city clock faces.
  - **Barlow** (Medium / SemiBold): condensed digital time readouts.
  - **iOS lock-screen faces** (`ios_*`): glass-text clock only.
- Don't add a new font unless the macOS original uses something none of these cover. If you do,
  add it to `1-common/fonts/` and check its license first (see the README's third-party assets
  section).
- Size text from the widget's size (usually `height`, or `min(width, height)` for square faces),
  never as fixed pixel sizes, so the widget scales with resizing.
- Keep a clear hierarchy: one dominant element (time, temperature, track title), then secondary
  labels with `labelSecondary` / reduced opacity.

## Layout and sizing

- Default aspect ratio is **1:1**. A **wide** layout kicks in at `width >= height * 2`: the
  original square content stays on the right, and a side panel fills the left. Follow the
  wide-mode pattern in [AGENTS.md](AGENTS.md#wide-mode-side-panel-layout).
- Derive spacing from `height`. Wide-panel constants used across the repo:
  - margin `height * 0.09`
  - card font `height * 0.052`
  - card spacing `height * 0.025`
- Cards: height ≈ `fontSize * 2.8`, radius ≈ `height * 0.25`. Event/category cards get a 3 px
  left pill (`radius: 1.5`); preset cards don't.
- Glass defaults (calendar's `main.xml`): corner radius 100, roundness 7.5, tint 10 %,
  refraction thickness 35, blur radius 6. Keep these unless the macOS original clearly differs.
- In panels, use a compact representation and cap the popup corner radius at 20. See
  [AGENTS.md](AGENTS.md#compact-panel-representation).
- Never let a resize or a content change (e.g. `9:59` → `10:00`) make the widget jump. Pre-measure
  the widest content with `TextMetrics` and reserve that space.

## Motion

- Motion should feel like macOS: short and eased, never bouncy or linear.
- Common durations: **150–180 ms** for hover and press, **280 ms** for layout and content
  transitions, around **500 ms** for larger state changes.
- The Glass / Solid switch (`StyleFade`) is a linear **150 ms** cross-fade by default. Users can
  change it or turn it off under Appearance → Style → Switch automatically → Advanced (`styleFadeMs`, 0 = off).
- Easing: `Easing.OutQuart` / `OutCubic` for things entering or settling, `InOutQuad` for
  back-and-forth transitions.
- Animate opacity, scale and position, not colors baked into the glass shader. Don't run
  per-frame timers for decoration. A desktop widget sits still for days; see the timer and power
  conventions in [AGENTS.md](AGENTS.md#timer--power-conventions).

## Interaction states

- Hover and press feedback use the card opacity tokens, not new colors.
- Hit targets are at least about 24 px even when the visual is smaller.
- Empty states are centered, short (e.g. "No upcoming events"), and around 45 % opacity.

## Visual review criteria

What a visual change is reviewed against. The pull request template links here.

- [ ] Matches a macOS / iOS reference (attach it to the PR).
- [ ] Looks right in Glass Dark, Glass Light, Solid Dark, Solid Light, and the fallback.
- [ ] Every color comes from a `MacOSColors` token, and none is hardcoded.
- [ ] Text and spacing scale from the widget size, and resizing doesn't jump.
- [ ] Wide (2:1) and panel layouts work, if the widget supports them.
- [ ] Idle CPU/GPU is flat: no always-on animation or polling.

## Contributing

Adding a widget, opening a pull request or suggesting an idea: see [CONTRIBUTING.md](CONTRIBUTING.md).
Only widgets with a macOS or iOS counterpart are accepted, and a new widget starts as a request issue.
