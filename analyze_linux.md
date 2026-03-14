# Pixelated Lava Lamp — Linux App

## Overview

A minimal Linux system tray / desktop widget app that renders a pixelated lava lamp with a fully transparent background. The lamp floats on screen as a small, always-on-top decoration. Built in C with GTK 4 and Cairo for the pixel-art simulation. Controllable via system tray, clicking the lamp, D-Bus interface, and a `lavalampctl` CLI tool.

---

## Visual Design

- **Style:** Low-resolution pixel art (chunky, retro aesthetic)
- **Resolution grid:** 48×120 virtual pixels, scaled at 2.0× by default (user-selectable: 1.5×, 2.0×, 2.5×)
- **Lamp body:** Outlined glass shape with a quadratic taper (widest at center, narrowing at top/bottom), metallic cap (top) and base (bottom)
- **Lava blobs:** 5 colored blobs that rise, merge, split, and sink inside the glass
- **Background:** Fully transparent (GTK window with RGBA visual, no decorations)
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
LavaLampApp (GtkApplication)
└── activate callback
    ├── TransparentWindow (GtkWindow)
    │   └── GtkDrawingArea
    │       └── Cairo draw callback
    │           ├── LavaSimulation (model)
    │           │   ├── Blob[] — array of blob structs
    │           │   └── simulation_update(dt, speed_multiplier) — physics step
    │           ├── PixelGridRenderer
    │           │   ├── Samples metaball field onto grid
    │           │   └── Outputs RGBA pixel buffer (cairo_image_surface_t)
    │           └── Renders pixel buffer to window (nearest-neighbor scaling)
    ├── SystemTrayIcon (libayatana-appindicator / StatusNotifierItem)
    │   └── GtkMenu: color presets, speed, size, click-through, quit
    ├── LampConfig (header)
    │   └── Grid dimensions, glass shape geometry, defaults
    └── D-Bus Interface (org.lavalamp.Control)
        └── Start, Stop, Toggle, SetColor, RandomColor, SetSpeed, Quit
```

### Key Components

| Component | Responsibility |
|---|---|
| `LavaSimulation` | Owns blob state, runs physics each tick |
| `PixelGridRenderer` | Converts continuous blob positions into a discrete RGBA pixel buffer via metaball sampling |
| `LavaLampScene` | GTK draw callback that drives the fixed-timestep update loop and paints the pixel texture via Cairo |
| `TransparentWindow` | Borderless, transparent `GtkWindow`; always on top; draggable; click-to-randomize color |
| `SystemTrayIcon` | System tray icon (flame) with color presets, speed, size, and click-through toggle via libayatana-appindicator |
| `LampConfig` | Central constants: grid size (48×120), glass shape geometry, default blob count (5), pixel scale |

---

## Window & Transparency

```c
// TransparentWindow setup
GtkWidget *window = gtk_window_new();
gtk_window_set_decorated(GTK_WINDOW(window), FALSE);           // borderless
gtk_window_set_default_size(GTK_WINDOW(window), width, height);

// RGBA visual for transparency
GdkDisplay *display = gdk_display_get_default();
// GTK 4 uses RGBA by default when compositing is available

// Always on top
gtk_window_set_keep_above(GTK_WINDOW(window), TRUE);

// Skip taskbar and pager
// Handled via GtkWindow type hint or X11/Wayland protocol

// Input passthrough for click-through mode
// X11: XShapeCombineRectangles with ShapeInput
// Wayland: compositor-specific (wlr-layer-shell or input-region)
```

- The Cairo drawing surface background is cleared to fully transparent
- Only the lamp outline and lava pixels are drawn — everything else is see-through
- The lamp can be dragged to any screen position (position saved between launches)
- Transparency requires a compositing window manager (standard on modern desktops)

---

## Display Server Compatibility

### X11 (Xorg)
- Transparency via RGBA visual + compositing manager (picom, compton, or built-in compositor)
- Always-on-top via `_NET_WM_STATE_ABOVE`
- Click-through via `XShapeCombineRectangles` on the input shape
- Drag via manual `GDK_BUTTON_PRESS` → `gtk_window_begin_move`
- System tray via XEmbed (StatusNotifierItem preferred)

### Wayland
- Transparency is native (compositors handle alpha by default)
- Always-on-top via `xdg_toplevel.set_on_top` or `wlr-layer-shell` (compositor-dependent)
- Click-through via `wl_surface.set_input_region`
- Drag via `xdg_toplevel.move`
- System tray via StatusNotifierItem (D-Bus based, compositor-independent)
- Note: Some features (exact positioning, global click-through) may be limited by compositor policy

### XWayland Fallback
- App can run under XWayland if native Wayland features are unavailable
- Detected at runtime; X11 code paths used as fallback

---

## User Interaction

- **Click:** Click the lamp body to randomize lava color (random hue, saturation 0.6–1.0, brightness 0.7–1.0)
- **Drag:** Click and drag the lamp body to reposition (position saved on quit)
- **System tray icon (flame):** Opens settings menu
  - Lava color → preset submenu (Orange, Red, Blue, Green, Purple, Pink) + Custom… (GtkColorChooserDialog)
  - Speed → Slow (0.25×), Normal (0.5×), Fast (1.0×)
  - Size → Small (1.5×), Medium (2.0×), Large (2.5×)
  - Click-through mode (on/off)
  - Quit

### D-Bus Interface

The app exposes `org.lavalamp.Control` on the session bus for external control:

| Method / Signal | Effect |
|---|---|
| `org.lavalamp.Control.Start()` | Resume animation |
| `org.lavalamp.Control.Stop()` | Pause animation |
| `org.lavalamp.Control.Toggle()` | Toggle pause/resume |
| `org.lavalamp.Control.SetColor(string hex)` | Set lava color by hex (e.g., `FF6600`) |
| `org.lavalamp.Control.SetColorRGB(double r, double g, double b)` | Set lava color by RGB floats |
| `org.lavalamp.Control.RandomColor()` | Pick random harmonious color |
| `org.lavalamp.Control.SetSpeed(string value)` | Set speed (`slow`/`normal`/`fast` or float) |
| `org.lavalamp.Control.Quit()` | Terminate the app |

D-Bus introspection XML is installed to `/usr/share/dbus-1/interfaces/`.

### CLI Tool: `lavalampctl`

A shell script that wraps `dbus-send` / `gdbus call` for terminal control:

```
lavalampctl start|stop|toggle
lavalampctl set-color <hex> | <r> <g> <b>
lavalampctl random-color
lavalampctl set-speed <slow|normal|fast|float>
lavalampctl about
lavalampctl stats [--json|--yaml|--txt|--md]
lavalampctl quit
```

The CLI detects whether the app is running via D-Bus name ownership (`org.lavalamp.Control`). If the app is not running, commands print an error and exit with status 1.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | C (C17) with GLib/GObject |
| UI framework | GTK 4 (transparent window, drawing area, color chooser) |
| Rendering | Cairo (image surface → nearest-neighbor scaled blit) |
| System tray | libayatana-appindicator3 (StatusNotifierItem, works on GNOME/KDE/XFCE/etc.) |
| IPC | D-Bus (GDBus from GLib) |
| Persistence | GKeyFile (`~/.config/lavalamp/config.ini`) |
| Build | Meson + Ninja, pkg-config for dependencies |
| Packaging | `.deb` (Debian/Ubuntu), `.rpm` (Fedora), Flatpak, AppImage |

---

## Implemented Features

- Transparent, borderless, draggable window (position persisted)
- 5-blob metaball lava simulation with temperature-driven buoyancy
- 48×120 pixel grid rendered to Cairo surface at 15 fps
- Tapered glass shape with metallic cap and base
- System tray icon (flame) with color presets, speed, size, and click-through controls
- Click-to-randomize-color on lamp body
- D-Bus interface (`org.lavalamp.Control`) for external control
- `lavalampctl` CLI tool with stats output (JSON/YAML/TXT/Markdown)
- All settings persisted via config file (color, speed, size, window position)
- No dock/taskbar entry (runs as tray-only application)
- Works on X11 and Wayland (with compositor-dependent limitations)

### Potential Future Enhancements

- Multiple lamp styles (tall/short, different base designs)
- Ambient light glow effect on surrounding pixels
- Idle detection: blobs settle when system is idle, wake up on input (via D-Bus `org.freedesktop.ScreenSaver`)
- Multiple lamps
- Autostart via XDG autostart (`~/.config/autostart/lavalamp.desktop`)
- Flatpak / Snap packaging for sandboxed distribution
- Wayland layer-shell support for proper desktop widget behavior

---

## Persistence

Settings are stored in `~/.config/lavalamp/config.ini` (XDG Base Directory compliant):

```ini
[lavalamp]
lava_color_r=1.0
lava_color_g=0.4
lava_color_b=0.0
speed=0.5
pixel_scale=2.0
window_position_x=1200
window_position_y=400
```

| Key | Type | Default |
|---|---|---|
| `lava_color_r/g/b` | double | 1.0 / 0.4 / 0.0 |
| `speed` | double | 0.5 |
| `pixel_scale` | double | 2.0 |
| `window_position_x/y` | double | Right edge, vertically centered |

Color, speed, and size are saved immediately on change. Window position is saved on quit. The config directory is created automatically if it does not exist.

---

## Performance Considerations

- The pixel grid is tiny (48×120 = 5,760 cells) — metaball sampling is trivially fast (5 blobs × 5,760 = 28,800 evaluations per frame)
- Rendering via `cairo_image_surface_create` from a raw RGBA pixel buffer avoids GPU overhead
- At 15 fps the CPU cost is negligible (<1% on any modern machine)
- No OpenGL/Vulkan needed; Cairo's software path is sufficient at this scale
- Timer-based redraw via `g_timeout_add` (66ms interval) keeps the event loop responsive
- Minimal dependencies: only GTK 4, Cairo, GLib, and libayatana-appindicator

---

## Build & Install

```bash
# Dependencies (Debian/Ubuntu)
sudo apt install libgtk-4-dev libcairo2-dev libayatana-appindicator3-dev meson ninja-build

# Dependencies (Fedora)
sudo dnf install gtk4-devel cairo-devel libayatana-appindicator-gtk3-devel meson ninja-build

# Build
meson setup builddir
meson compile -C builddir

# Install
sudo meson install -C builddir

# Run
lavalamp &
```

### Desktop Entry

Installed to `/usr/share/applications/lavalamp.desktop`:

```ini
[Desktop Entry]
Name=Lava Lamp
Comment=Pixelated lava lamp desktop widget
Exec=lavalamp
Icon=lavalamp
Type=Application
Categories=Utility;
StartupNotify=false
X-GNOME-Autostart-enabled=false
```
