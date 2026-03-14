# LavaLamp

A pixelated lava lamp that floats on your macOS desktop. Runs as a transparent, always-on-top window with a menu bar icon -- no dock icon, no chrome, just a tiny lamp with simulated blob physics.

```
       ███
     ███████
    /-------\
   /   ██    \
  /   ████    \
 |   ██████    |
|    ██████     |
|     ████      |
|      ██       |
|               |
 |    ████     |
  \  ██████   /
   \  ████   /
    \-------/
   ███████████
  █████████████
```

## Features

- **Pixel-art rendering** -- 48x120 grid rendered via SpriteKit at 15 fps
- **5-blob metaball simulation** -- temperature-driven buoyancy, drag, and collision within a tapered glass shape
- **Menu bar control** -- flame icon with submenus for color presets (Orange, Red, Blue, Green, Purple, Pink, custom picker), speed (Slow/Normal/Fast), and size (Small/Medium/Large)
- **Click to randomize** -- click the lamp body to pick a new harmonious color
- **Click-through mode** -- toggle to let clicks pass through the lamp to windows below
- **Draggable** -- reposition the lamp anywhere; position persists across launches
- **URL scheme** (`lavalamp://`) -- control the lamp from scripts, Shortcuts, or other apps
- **CLI tool** (`lavalampctl`) -- full terminal control with JSON, YAML, Markdown, and text output
- **No dock icon** -- runs as a menu bar-only app (LSUIElement)

## Requirements

- macOS 13+
- Xcode 15+ (for building)

No external dependencies -- uses only AppKit, SpriteKit, SwiftUI, and Foundation.

## Build & Run

```bash
./build_and_run.sh
```

Or manually:

```bash
xcodebuild -project LavaLamp.xcodeproj -scheme LavaLamp -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/LavaLamp.app
```

## CLI (`lavalampctl`)

A bash wrapper around the `lavalamp://` URL scheme for terminal control.

```bash
lavalampctl start                      # Resume animation
lavalampctl stop                       # Pause animation
lavalampctl toggle                     # Toggle start/stop
lavalampctl set-color FF6600           # Set color by hex
lavalampctl set-color 0.2 0.4 1.0      # Set color by RGB floats (0.0-1.0)
lavalampctl random-color               # Pick a random harmonious color
lavalampctl set-speed slow             # Set speed (slow/normal/fast or float)
lavalampctl set-monitor 2              # Move lamp to display N (1=main)
lavalampctl about                      # Show app info
lavalampctl stats                      # Show lamp stats (text)
lavalampctl stats --json               # Stats as JSON
lavalampctl stats --yaml               # Stats as YAML
lavalampctl stats --md                 # Stats as Markdown
lavalampctl quit                       # Quit the app
```

The `stats` command reads directly from UserDefaults, so it works even without the app running.

## URL Scheme

Control the lamp programmatically via the `lavalamp://` URL scheme:

```
lavalamp://start
lavalamp://stop
lavalamp://toggle
lavalamp://set-color?hex=FF6600
lavalamp://set-color?r=0.2&g=0.4&b=1.0
lavalamp://random-color
lavalamp://set-speed?value=fast
lavalamp://set-monitor?display=2
lavalamp://quit
```

## Architecture

| File | Role |
|---|---|
| `LavaLampApp.swift` | SwiftUI entry point |
| `AppDelegate.swift` | Window setup, URL scheme handling, settings persistence |
| `LavaLampScene.swift` | SpriteKit scene with fixed-timestep update loop |
| `LavaSimulation.swift` | Blob physics: temperature, buoyancy, drag, wall collisions |
| `PixelGridRenderer.swift` | Metaball field sampling, glass/cap/base rendering |
| `TransparentWindow.swift` | Borderless NSWindow with dragging and click detection |
| `MenuBarController.swift` | Menu bar icon and dropdown controls |
| `LampConfig.swift` | Grid dimensions, glass geometry, defaults |

## Author

**Lars Gregori** -- [larsgregori.de](https://larsgregori.de) -- [GitHub](https://github.com/choas)
