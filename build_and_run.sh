#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$PROJECT_DIR/LavaLamp.xcodeproj"
SCHEME="LavaLamp"
BUILD_DIR="$PROJECT_DIR/build"
APP="$BUILD_DIR/Build/Products/Debug/LavaLamp.app"

echo "==> Building $SCHEME..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build

echo "==> Launching $SCHEME..."
open "$APP"
