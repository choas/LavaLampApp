# Pixelated Lava Lamp — macOS App

## Overview

A minimal macOS menu bar / desktop widget app that renders a pixelated lava lamp with a fully transparent background. The lamp floats on screen as a small, always-on-top decoration. Built entirely in Swift using SpriteKit for the pixel-art simulation. Controllable via menu bar, clicking the lamp, a `lavalamp://` URL scheme, and a `lavalampctl` CLI tool.

---

## Visual Design

- **Style:** Low-resolution pixel art (chunky, retro aesthetic)
- **Resolution grid:** 48×120 virtual pixels, scaled at 2.0× by default (user-selectable: 1.5×, 2.0×, 2.5×)
- **Lamp body:** Outlined glass shape with a quadratic taper (widest at center, narrowing at top/bottom), metallic cap (top) and base (bottom)
- **Lava blobs:** 5 colored blobs that rise, merge, split, and sink inside the glass
- **Background:** Fully transparent (`NSWindow` with `.clear` background, no title bar)
- **Color palette:** User-configurable lava color (default: orange RGB 1.0, 0.4, 0.0) with multi-level glow (core, bright highlight, outer glow with transparency)

---

## Lava Simulation

The lava behaviour is the core of the app. It does not need to be physically accurate — it needs to *look* right at pixel scale.

### Approach: Metaball Grid Sampling

1. Maintain a set of **circle-shaped blobs** with properties:
   - position (x, y) — continuous float, snapped to grid for rendering
   - radius (6–10 pixels)
   - velocity (dx, dy) — clamped to ±15 horizontal, ±20 vertical
   - temperature (0.0–1.0, controls buoyancy)

2. Each frame, update blob physics:
   - **Heating:** Blobs in the bottom 30% gain temperature (rate: 0.8)
   - **Cooling:** Blobs in the top 30% lose temperature (rate: 0.6)
   - **Ambient drift:** Temperature drifts toward 0.5 at ±10% per frame
   - **Buoyancy:** `dy -= (temperature - 0.5) × 40.0 × dt` — hot blobs rise, cold blobs sink
   - **Drag:** Velocity damped by 0.98× per frame, plus random horizontal perturbation (±3.0)
   - **Wall collision:** Blobs bounce off the tapered glass outline (0.5× horizontal, 0.3× vertical restitution)

3. **Render to pixel grid** using a metaball field:
   - For each cell in the 48×120 grid, sum the field contributions from all blobs: `f(x,y) = Σ (r_i² / ((x-x_i)² + (y-y_i)²))`
   - `f > 1.4` → core lava (solid color)
   - `f > 1.0` → bright highlight (+60 RGB)
   - `f > 0.6` → outer glow (reduced alpha)
   - This naturally produces merging/splitting visuals without explicit blob-merge logic

4. **Frame rate:** Fixed at 15 fps for a deliberately choppy pixel-art feel, with a fixed-timestep update loop and speed multiplier (0.25×–1.0×)

---

## Architecture

```
LavaLampApp (SwiftUI @main)
└── AppDelegate (NSApplicationDelegate)
    ├── TransparentWindow (NSWindow)
    │   └── SKView
    │       └── LavaLampScene (SKScene)
    │           ├── LavaSimulation (model)
    │           │   ├── [Blob] — array of blob structs
    │           │   └── update(dt:speedMultiplier:) — physics step
    │           ├── PixelGridRenderer
    │           │   ├── Samples metaball field onto grid
    │           │   └── Outputs RGBA pixel buffer
    │           └── SKSpriteNode with SKTexture
    │               └── Renders pixel buffer to screen (.nearest filtering)
    ├── MenuBarController
    │   └── NSStatusItem (flame icon) with dropdown: color presets, speed, size, click-through, quit
    ├── LampConfig (enum)
    │   └── Grid dimensions, glass shape geometry, defaults
    └── URL Scheme Handler (lavalamp://)
        └── start, stop, toggle, set-color, random-color, set-speed, quit
```

### Key Components

| Component | Responsibility |
|---|---|
| `LavaSimulation` | Owns blob state, runs physics each tick |
| `PixelGridRenderer` | Converts continuous blob positions into a discrete RGBA pixel buffer via metaball sampling |
| `LavaLampScene` | SpriteKit scene that drives the fixed-timestep update loop and draws the pixel texture |
| `TransparentWindow` | Borderless, transparent `NSWindow` subclass; always on top; draggable; click-to-randomize color |
| `MenuBarController` | System tray icon (flame) with color presets, speed, size, and click-through toggle |
| `LampConfig` | Central constants: grid size (48×120), glass shape geometry, default blob count (5), pixel scale |

---

## Window & Transparency

```swift
// TransparentWindow setup
window.isOpaque = false
window.backgroundColor = .clear
window.level = .floating
window.styleMask = [.borderless]
window.hasShadow = false
window.ignoresMouseEvents = false  // allow drag; toggle for click-through mode
window.collectionBehavior = [.canJoinAllSpaces, .stationary]
```

- The SKScene background is also `.clear`
- Only the lamp outline and lava pixels are drawn — everything else is see-through
- The lamp can be dragged to any screen position (position saved between launches)

---

## User Interaction

- **Click:** Click the lamp body to randomize lava color (random hue, saturation 0.6–1.0, brightness 0.7–1.0)
- **Drag:** Click and drag the lamp body to reposition (position saved on quit)
- **Menu bar icon (flame):** Opens settings menu
  - Lava color → preset submenu (Orange, Red, Blue, Green, Purple, Pink) + Custom… (NSColorPanel)
  - Speed → Slow (0.25×), Normal (0.5×), Fast (1.0×)
  - Size → Small (1.5×), Medium (2.0×), Large (2.5×)
  - Click-through mode (on/off)
  - Quit

### URL Scheme

The app registers the `lavalamp://` URL scheme for external control:

| URL | Effect |
|---|---|
| `lavalamp://start` | Resume animation |
| `lavalamp://stop` | Pause animation |
| `lavalamp://toggle` | Toggle pause/resume |
| `lavalamp://set-color?hex=FF6600` | Set lava color by hex |
| `lavalamp://set-color?r=0.2&g=0.4&b=1.0` | Set lava color by RGB floats |
| `lavalamp://random-color` | Pick random harmonious color |
| `lavalamp://set-speed?value=fast` | Set speed (slow/normal/fast or float) |
| `lavalamp://quit` | Terminate the app |

### CLI Tool: `lavalampctl`

A bash script that wraps `open lavalamp://…` for terminal control:

```
lavalampctl start|stop|toggle
lavalampctl set-color <hex> | <r> <g> <b>
lavalampctl random-color
lavalampctl set-speed <slow|normal|fast|float>
lavalampctl about
lavalampctl stats [--json|--yaml|--txt|--md]
lavalampctl quit
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI framework | SwiftUI (menu bar popover) + AppKit (transparent window) |
| Rendering | SpriteKit (SKTexture from pixel buffer) |
| Persistence | UserDefaults |
| Build | Xcode 15+, target macOS 13+ |

---

## Implemented Features

- Transparent, borderless, draggable window (position persisted)
- 5-blob metaball lava simulation with temperature-driven buoyancy
- 48×120 pixel grid rendered to SKTexture at 15 fps
- Tapered glass shape with metallic cap and base
- Menu bar icon (flame) with color presets, speed, size, and click-through controls
- Click-to-randomize-color on lamp body
- `lavalamp://` URL scheme for external control
- `lavalampctl` CLI tool with stats output (JSON/YAML/TXT/Markdown)
- All settings persisted via UserDefaults (color, speed, size, window position)
- App runs as LSUIElement (no dock icon, menu bar only)
- App sandbox enabled, no external dependencies

### Potential Future Enhancements

- Multiple lamp styles (tall/short, different base designs)
- Ambient light glow effect on surrounding pixels
- Idle detection: blobs settle when Mac is idle, wake up on input
- Multiple lamps
- Launch at login

---

## Persistence

Settings are stored in UserDefaults under the app's bundle ID (`com.lavalamp.LavaLamp`):

| Key | Type | Default |
|---|---|---|
| `lavaColorR/G/B` | Double | 1.0 / 0.4 / 0.0 |
| `speed` | Double | 0.5 |
| `pixelScale` | Double | 2.0 |
| `windowPositionX/Y` | Double | Right edge, vertically centered |

Color, speed, and size are saved immediately on change. Window position is saved on quit.

---

## Performance Considerations

- The pixel grid is tiny (48×120 = 5,760 cells) — metaball sampling is trivially fast (5 blobs × 5,760 = 28,800 evaluations per frame)
- Rendering via `SKTexture(data:size:)` from a raw RGBA pixel buffer avoids per-node overhead
- At 15 fps the CPU cost is negligible (<1% on any modern Mac)
- No Metal compute needed; SpriteKit's software path is sufficient at this scale
- Fully sandboxed, no network access, no external dependencies
