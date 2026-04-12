# macos-widgets

macOS Tahoe / iOS 18 style widgets for KDE Plasma 6.

## Status

Phase 1: scaffolding + liquid-glass background component. One test widget (`glass-test`).

## Requirements

- KDE Plasma 6.x
- Qt 6.x with `qsb` (from `qt6-base-dev-tools`) — only needed if you rebuild shaders
- `jq`, `zip`, `kpackagetool6`

## Install

```
./install.sh glass-test          # single widget
./install.sh --all               # every widget in packages/
```

Then add the "macOS Glass Test" widget to the desktop.

## Package

```
./build-shaders.sh               # rebuild .qsb files (commit the outputs)
./package.sh glass-test          # -> 2-packaged/glass-test-0.1.plasmoid
```

## Layout

- `1-common/` — shared QML components, shaders, fonts
- `packages/` — individual widget sources; each symlinks into `1-common/`
- `2-packaged/` — `.plasmoid` build outputs
- `0-images/` — screenshots per widget

## Liquid glass

`1-common/components/LiquidGlass.qml` samples `Plasmoid.containment.wallpaperGraphicsObject`, blurs it with `MultiEffect`, and runs a custom GLSL shader for edge refraction, tint, and specular. Works on desktop containments only — falls back to a flat translucent rect elsewhere (including `plasmoidviewer`).
