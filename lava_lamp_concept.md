# Pixelated Lava Lamp — macOS App Concept

## Overview

A minimal macOS menu bar / desktop widget app that renders a pixelated lava lamp with a fully transparent background. The lamp floats on screen as a small, always-on-top decoration. Built entirely in Swift using SpriteKit for the pixel-art simulation.

---

## Visual Design

- **Style:** Low-resolution pixel art (chunky, retro aesthetic)
- **Resolution grid:** ~48×120 virtual pixels, scaled up to crisp blocky rendering (~4×4 points per pixel)
- **Lamp body:** Outlined glass shape with a metallic cap (top) and base (bottom), drawn as pixel sprites
- **Lava blobs:** 4–6 colored blobs that rise, merge, split, and sink inside the glass
- **Background:** Fully transparent (`NSWindow` with `.clear` background, no title bar)
- **Color palette:** User-configurable lava color (default: classic orange/red) with a subtle inner glow mapped to adjacent pixel brightness

---

## Lava Simulation

The lava behaviour is the core of the app. It does not need to be physically accurate — it needs to *look* right at pixel scale.

### Approach: Metaball Grid Sampling

1. Maintain a set of **circle-shaped blobs** with properties:
   - position (x, y) — continuous float, snapped to grid for rendering
   - radius
   - velocity (dx, dy)
   - temperature (controls buoyancy)

2. Each frame, update blob physics:
   - **Heating:** Blobs near the bottom gain temperature → rise (negative dy)
   - **Cooling:** Blobs near the top lose temperature → sink (positive dy)
   - **Buoyancy:** Vertical velocity influenced by temperature difference from ambient
   - **Drag:** Slow horizontal drift with slight random perturbation
   - **Wall collision:** Blobs stay within the glass outline, with soft bounce

3. **Render to pixel grid** using a metaball field:
   - For each cell in the 48×120 grid, sum the field contributions from all blobs: `f(x,y) = Σ (r_i² / ((x-x_i)² + (y-y_i)²))`
   - If `f > threshold` → pixel is "lava" (filled with lava color)
   - If `f` is near the threshold → pixel gets a brighter highlight (edge glow)
   - This naturally produces merging/splitting visuals without explicit blob-merge logic

4. **Frame rate:** Target 12–15 fps for a deliberately choppy pixel-art feel (configurable up to 30 fps for smoother motion)

---

## Architecture

```
LavaLampApp (SwiftUI App)
├── AppDelegate
│   └── Creates transparent, borderless NSWindow (always on top, click-through optional)
├── LavaLampView (SpriteKit SKView embedded in NSHostingView)
│   └── LavaLampScene (SKScene)
│       ├── LavaSimulation (model)
│       │   ├── [Blob] — array of blob structs
│       │   └── update(dt:) — physics step
│       ├── PixelGridRenderer
│       │   ├── Samples metaball field onto grid
│       │   └── Outputs grid of color values
│       └── SKSpriteNode grid or SKTexture
│           └── Renders pixel grid to screen
├── MenuBarController
│   └── NSStatusItem with dropdown: color picker, speed, quit
└── Settings
    └── UserDefaults: lava color, lamp size, frame rate, position
```

### Key Components

| Component | Responsibility |
|---|---|
| `LavaSimulation` | Owns blob state, runs physics each tick |
| `PixelGridRenderer` | Converts continuous blob positions into a discrete pixel grid via metaball sampling |
| `LavaLampScene` | SpriteKit scene that drives the update loop and draws the pixel texture |
| `TransparentWindow` | Borderless, transparent `NSWindow` subclass; always on top; draggable |
| `MenuBarController` | System tray icon with settings popover (color, speed, quit) |

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

- **Drag:** Click and drag the lamp body to reposition
- **Right-click / Menu bar icon:** Opens settings
  - Lava color (color well)
  - Lamp size (small / medium / large)
  - Animation speed (slow / normal / fast)
  - Click-through mode (on/off)
  - Launch at login
  - Quit

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

## Implementation Phases

### Phase 1 — Core rendering
- Transparent borderless window
- Static pixel-art lamp outline (cap, glass, base) drawn as a sprite
- Metaball simulation with 4 blobs
- Pixel grid renderer → SKTexture each frame
- Basic drag-to-move

### Phase 2 — Polish & settings
- Menu bar icon with settings popover
- Color picker for lava
- Animation speed control
- Save/restore window position
- Launch-at-login support

### Phase 3 — Nice-to-haves
- Multiple lamp styles (tall/short, different base designs)
- Ambient light glow effect on surrounding pixels
- Idle detection: blobs settle when Mac is idle, wake up on input
- Multiple lamps

---

## Performance Considerations

- The pixel grid is tiny (48×120 = 5,760 cells) — metaball sampling is trivially fast
- Rendering via `SKTexture(data:size:)` from a raw pixel buffer avoids per-node overhead
- At 12–15 fps the CPU cost is negligible (<1% on any modern Mac)
- No Metal compute needed; SpriteKit's software path is sufficient at this scale
