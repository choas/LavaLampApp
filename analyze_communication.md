# External Communication Analysis: Controlling the Lava Lamp from Outside

## Goal

Enable external processes to start, stop, and control the lava lamp app (color, speed, visibility) without using the GUI menu bar.

## Current Architecture

The app is a native macOS SpriteKit application. All control flows through `MenuBarController` callbacks into `AppDelegate`, which mutates `LavaLampScene` properties. There is no external interface — everything is in-process and UI-driven.

---

## Option 1: macOS Distributed Notifications (NSDistributedNotificationCenter)

**How it works:** Any process on the system can post a named notification with a userInfo dictionary. The lava lamp app listens for specific notification names and reacts.

**Example usage:**
```bash
# From terminal or script
osascript -e 'tell application "System Events" to do shell script \
  "swift -e \"import Foundation; DistributedNotificationCenter.default().postNotificationName(NSNotification.Name(\\\"com.lavalamp.setColor\\\"), object: nil, userInfo: [\\\"color\\\": \\\"blue\\\"], deliverImmediately: true)\""'
```

Or more practically, a small Swift CLI companion:
```bash
lavalampctl set-color blue
lavalampctl stop
lavalampctl start
```

| Pros | Cons |
|------|------|
| Zero network exposure — purely local IPC | macOS-only mechanism |
| No port binding, no firewall concerns | Payload is limited to property list types |
| Trivial to implement (< 30 lines in the app) | No request/response — fire-and-forget |
| Works from any language that can call ObjC/Swift | No authentication built in |

**Implementation effort:** Very low. Add a `DistributedNotificationCenter` observer in `AppDelegate` and dispatch to existing callbacks.

**Best for:** Local scripting, Shortcuts.app integration, simple automation.

---

## Option 2: URL Scheme (Custom Protocol Handler)

**How it works:** Register a custom URL scheme (e.g. `lavalamp://`). Any process can open a URL to control the app.

**Example usage:**
```bash
open "lavalamp://set-color?r=0.2&g=0.4&b=1.0"
open "lavalamp://stop"
open "lavalamp://start"
open "lavalamp://set-speed?value=fast"
```

| Pros | Cons |
|------|------|
| Works from terminal, browser, Shortcuts, other apps | macOS-only (but standard macOS pattern) |
| No networking, no port management | No response channel — one-way |
| Familiar pattern for macOS users | Requires Info.plist URL scheme registration |
| Can be triggered from web pages or Raycast | URL encoding can be awkward for complex payloads |

**Implementation effort:** Low. Add URL scheme to Info.plist, implement `application(_:open:)` in `AppDelegate`.

**Best for:** Quick triggers from Raycast, Shortcuts, browser bookmarklets, Alfred workflows.

---

## Option 3: CLI via Unix Domain Socket

**How it works:** The app listens on a Unix domain socket (e.g. `~/.lavalamp.sock`). A companion CLI tool connects, sends a JSON command, and receives a JSON response.

**Example usage:**
```bash
lavalampctl start
lavalampctl stop
lavalampctl set-color --hex "#FF6600"
lavalampctl status
# Output: {"running": true, "color": "#FF6600", "speed": "normal"}
```

| Pros | Cons |
|------|------|
| Full request/response (can query state) | Requires building a CLI companion binary |
| No network exposure — file-system permissions | Socket file lifecycle management |
| Fast, low overhead | Slightly more implementation effort |
| Scriptable from any language | Need to handle concurrent connections |

**Implementation effort:** Medium. Implement socket server in the app, build a small CLI client.

**Best for:** Scripting, status queries, integration with shell workflows and cron jobs.

---

## Option 4: Local HTTP/REST Server

**How it works:** The app starts a lightweight HTTP server on localhost (e.g. `http://127.0.0.1:7390`).

**Example usage:**
```bash
curl http://localhost:7390/start
curl http://localhost:7390/stop
curl -X POST http://localhost:7390/color -d '{"hex": "#FF6600"}'
curl http://localhost:7390/status
```

| Pros | Cons |
|------|------|
| Universal — works from any language, any tool | Binds a TCP port (port conflicts possible) |
| Request/response with status codes | Technically network-accessible unless firewalled |
| Can serve a tiny web control panel | Heavier dependency (HTTP framework or raw sockets) |
| Easy to extend with new endpoints | Overkill for simple on/off control |

**Implementation effort:** Medium. Use a lightweight Swift HTTP library (e.g. `Swifter`, `Vapor`, or raw `NWListener`). Apple's `Network.framework` `NWListener` can do this without external dependencies.

**Best for:** Integration with Home Assistant, webhook-driven automation, web dashboards, cross-machine control.

---

## Option 5: AppleScript / JXA (JavaScript for Automation)

**How it works:** Expose an AppleScript dictionary (`.sdef` file) so the app is scriptable via `osascript` or Shortcuts.

**Example usage:**
```applescript
tell application "LavaLamp"
    start
    set lava color to {255, 102, 0}
    set speed to "fast"
    stop
end tell
```

| Pros | Cons |
|------|------|
| Deep macOS integration (Shortcuts, Automator) | Requires defining a scripting dictionary (.sdef) |
| Familiar to macOS power users | AppleScript syntax is arcane |
| Bi-directional — can query state | More boilerplate than notifications |
| Works with Siri Shortcuts | macOS-only |

**Implementation effort:** Medium-high. Requires `.sdef` file, `NSScriptCommand` subclasses, and Info.plist entries.

**Best for:** Siri integration, Shortcuts.app, users who already use AppleScript workflows.

---

## Option 6: XPC Service

**How it works:** The app registers a Mach service. A privileged or unprivileged CLI tool connects over XPC to send commands.

| Pros | Cons |
|------|------|
| Apple's recommended IPC mechanism | Significant implementation complexity |
| Type-safe with Codable protocols | Requires entitlements and provisioning |
| Supports bi-directional communication | Overkill for this use case |
| Secure — process-level identity verification | Hard to use from non-Swift callers |

**Implementation effort:** High. Not recommended unless the app needs privileged operations.

---

## Recommendation

For this project, a **two-phase approach** makes the most sense:

### Phase 1 — Distributed Notifications (implement first)
- Fastest to implement (< 1 hour)
- Covers the core need: external start/stop/color/speed control
- Works immediately with shell scripts, Swift tools, and Shortcuts

### Phase 2 — URL Scheme (add next)
- Enables control from Raycast, Alfred, browser, and Shortcuts.app
- Complements notifications with a more user-friendly trigger mechanism

### Phase 3 (optional) — Local REST Server
- Only if cross-machine control or Home Assistant integration is needed
- Use `Network.framework` `NWListener` to avoid external dependencies

### Commands to support

| Command | Parameters | Notes |
|---------|------------|-------|
| `start` | — | Resume animation (unpause scene) |
| `stop` | — | Pause animation |
| `toggle` | — | Toggle between start/stop |
| `set-color` | `hex` or `r,g,b` | Change lava color |
| `random-color` | — | Pick a random harmonious color |
| `set-speed` | `slow` / `normal` / `fast` or float | Change speed multiplier |
| `status` | — | Return current state (needs response channel) |
| `quit` | — | Terminate the app |
