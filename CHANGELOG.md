# Changelog

All notable changes to the LavaLamp app will be documented in this file.

## [1.0.0] - 2026-03-14

### Added
- Pixelated lava lamp simulation running as a macOS menu bar app
- SceneKit-based rendering with pixel grid effect
- Menu bar controller with color change on click
- Configurable lamp title parameter (including `$time` for live clock display)
- HTTP server for remote control (`--port` parameter)
- Web interface for browser-based control (`--web` parameter)
- URL scheme support (`lavalamp://`)
- `lavalampctl` CLI tool for controlling the app (stats, about, random-color, and more)
- Build and run script (`build_and_run.sh`)
- Network server entitlement for HTTP functionality
