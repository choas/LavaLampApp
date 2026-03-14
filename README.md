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
- **Title label** -- display custom text below the lamp; use `$time` for a live clock
- **URL scheme** (`lavalamp://`) -- control the lamp from scripts, Shortcuts, or other apps
- **CLI tool** (`lavalampctl`) -- full terminal control with JSON, YAML, Markdown, and text output
- **HTTP server & web UI** -- start a built-in HTTP server and control the lamp from a browser
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
lavalampctl start                        # Resume animation
lavalampctl stop                         # Pause animation
lavalampctl toggle                       # Toggle start/stop
lavalampctl set-color FF6600             # Set color by hex
lavalampctl set-color 0.2 0.4 1.0        # Set color by RGB floats (0.0-1.0)
lavalampctl random-color                 # Pick a random harmonious color
lavalampctl set-speed slow               # Set speed (slow/normal/fast or float)
lavalampctl set-title "My Lamp"          # Set title below the lamp
lavalampctl set-title '$time'            # Show a live clock as the title
lavalampctl set-title-font Menlo         # Set title font name
lavalampctl set-title-font-size 14       # Set title font size
lavalampctl http --port 8080             # Start HTTP server on port
lavalampctl http --stop                  # Stop HTTP server
lavalampctl web                          # Open web UI (default port 8080)
lavalampctl web --port 9090              # Open web UI on custom port
lavalampctl about                        # Show app info
lavalampctl stats                        # Show lamp stats (text)
lavalampctl stats --json                 # Stats as JSON
lavalampctl stats --yaml                 # Stats as YAML
lavalampctl stats --md                   # Stats as Markdown
lavalampctl setup < config.yaml          # Apply config from file (YAML or JSON)
lavalampctl quit                         # Quit the app
```

The `stats` command reads directly from UserDefaults, so it works even without the app running. The output of `stats --yaml` or `stats --json` can be piped back through `setup` to restore settings.

An example configuration is included in `example/nice_green.yaml`.

## HTTP Server & Web UI

Start a built-in HTTP server to control the lamp from a browser or via HTTP requests:

```bash
lavalampctl web                    # Start server and open http://localhost:8080/
lavalampctl http --port 8080       # Start server without opening browser
lavalampctl http --stop            # Stop the server
```

The web UI provides color picker, speed slider, title controls, and real-time status. HTTP endpoints are also available for scripting:

```
GET /status            # Current state as JSON
GET /set-color?hex=FF6600
GET /set-speed?value=0.75
GET /set-title?text=Hello
GET /random-color
GET /play, /stop, /toggle
GET /help              # List all endpoints
```

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
lavalamp://set-title?text=Hello
lavalamp://set-title-font?name=Menlo
lavalamp://set-title-font-size?value=14
lavalamp://http?port=8080
lavalamp://web?port=8080
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
| `HTTPServer.swift` | Lightweight HTTP server and web UI using Network.framework |
| `LampConfig.swift` | Grid dimensions, glass geometry, defaults |

## License

Apache License 2.0 -- see [LICENSE](LICENSE) for details.

## Author

**Lars Gregori** -- [larsgregori.de](https://larsgregori.de) -- [GitHub](https://github.com/choas)
