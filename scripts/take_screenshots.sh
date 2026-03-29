#!/bin/bash
#
# App Store Screenshot Automation for Nami
# Usage: ./scripts/take_screenshots.sh
#
# Prerequisites:
# - Xcode command line tools installed
# - Nami project builds successfully
#

set -e

SIMULATOR_NAME="iPhone 17 Pro"
SCHEME="Nami"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/Screenshots"
BUNDLE_ID="com.imai.Nami"

echo "📸 Nami App Store Screenshot Automation"
echo "========================================"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Find simulator UDID
UDID=$(xcrun simctl list devices available | grep "$SIMULATOR_NAME" | head -1 | grep -oE '[A-F0-9-]{36}')
if [ -z "$UDID" ]; then
    echo "❌ Simulator '$SIMULATOR_NAME' not found"
    exit 1
fi
echo "✅ Simulator: $SIMULATOR_NAME ($UDID)"

# Boot simulator
echo "🔄 Booting simulator..."
xcrun simctl boot "$UDID" 2>/dev/null || true
sleep 3

# Set status bar to 9:41 with full signal
echo "📱 Setting status bar..."
xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4

# Build with SCREENSHOT_MODE
echo "🔨 Building with SCREENSHOT_MODE..."
cd "$PROJECT_DIR"
xcodebuild -scheme "$SCHEME" \
    -destination "id=$UDID" \
    -derivedDataPath "$PROJECT_DIR/.screenshot-build" \
    build 2>&1 | tail -3

# Find the built app
APP_PATH=$(find "$PROJECT_DIR/.screenshot-build" -name "Nami.app" -path "*/Debug-iphonesimulator/*" | head -1)
if [ -z "$APP_PATH" ]; then
    echo "❌ Built app not found"
    exit 1
fi
echo "✅ App: $APP_PATH"

# Install app
echo "📦 Installing app..."
xcrun simctl install "$UDID" "$APP_PATH"

# Launch with SCREENSHOT_MODE argument
echo "🚀 Launching with SCREENSHOT_MODE..."
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID" SCREENSHOT_MODE
sleep 5

# Take screenshots
echo ""
echo "📸 Taking screenshots..."
echo "   Please navigate to each screen manually in the simulator."
echo "   Press Enter after positioning each screen."
echo ""

SCREENS=("01_GraphView" "02_Widgets" "03_StatsView" "04_MonthlyReport" "05_RecordingSheet")

for screen in "${SCREENS[@]}"; do
    echo "📱 Ready for: $screen"
    echo "   Navigate to the correct screen, then press Enter..."
    read -r
    xcrun simctl io "$UDID" screenshot "$OUTPUT_DIR/$screen.png"
    echo "   ✅ Saved: $OUTPUT_DIR/$screen.png"
done

# Reset status bar
echo ""
echo "🔄 Resetting status bar..."
xcrun simctl status_bar "$UDID" clear

# Cleanup
echo "🧹 Cleaning up screenshot mode data..."
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

echo ""
echo "✅ Done! Screenshots saved to: $OUTPUT_DIR/"
ls -la "$OUTPUT_DIR/"
