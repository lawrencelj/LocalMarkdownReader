#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$PROJECT_ROOT/.build-intel"
DIST_DIR="$PROJECT_ROOT/dist"
APP_NAME="Markdown Reader"
EXECUTABLE_NAME="MarkdownReader-macOS"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/MarkdownReader-macOS-x86_64.zip"

export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/swift-module-cache"
export XDG_CACHE_HOME="$BUILD_ROOT/cache"

mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE" "$XDG_CACHE_HOME"

echo "Building $EXECUTABLE_NAME for Intel macOS (x86_64)..."
swift build \
    --package-path "$PROJECT_ROOT" \
    --scratch-path "$BUILD_ROOT" \
    --configuration release \
    --product "$EXECUTABLE_NAME" \
    --arch x86_64

BIN_DIR="$(swift build \
    --package-path "$PROJECT_ROOT" \
    --scratch-path "$BUILD_ROOT" \
    --configuration release \
    --arch x86_64 \
    --show-bin-path)"

rm -rf "$APP_BUNDLE" "$ZIP_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BIN_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp "$PROJECT_ROOT/Packaging/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_ROOT/Packaging/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

while IFS= read -r resource_bundle; do
    cp -R "$resource_bundle" "$APP_BUNDLE/Contents/Resources/"
done < <(find "$BIN_DIR" -maxdepth 1 -type d -name '*.bundle' -print)

chmod +x "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
codesign --force --deep --sign - "$APP_BUNDLE"

ARCHITECTURES="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME")"
if [[ "$ARCHITECTURES" != "x86_64" ]]; then
    echo "Expected an x86_64 executable, found: $ARCHITECTURES" >&2
    exit 1
fi

plutil -lint "$APP_BUNDLE/Contents/Info.plist"
codesign --verify --deep --strict "$APP_BUNDLE"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Built: $APP_BUNDLE"
echo "Archive: $ZIP_PATH"
