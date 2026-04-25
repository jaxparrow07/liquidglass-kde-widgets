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
- `MacOSColors { id: colors; themeMode: plasmoid.configuration.themeMode }` — light/dark/system color tokens. Use `colors.glassTint`, `colors.labelPrimary`, etc.; don't hardcode colors.
- Standard glass property bindings in every main.qml (cornerRadius, roundnessX10/10, refractThickness, refractIORx100/100, refractScale, tintAlphaPct/100, chromaStrengthPct/100, specStrengthPct/100, realtimeRefraction). Config stores fractional values scaled by 100 (or 10 for roundness) because kcfg entries are Int.
- Plasmoid config lives in `contents/config/main.xml` (kcfg) + `contents/config/config.qml` (ConfigModel) + `contents/ui/config/ConfigGeneral.qml` (Kirigami.FormLayout with `cfg_*` alias properties). The three files must agree entry-by-entry.
- Widget-specific QML components go under `contents/ui/widget/` (e.g. calendar's `TodayBadge.qml`, clock-square's `TickRing.qml` and `DigitalTime.qml`).

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

## Plan files

Ongoing design decisions for in-progress work may live in `~/.claude/plans/` outside the repo. When resuming work, check there before making architectural assumptions.
