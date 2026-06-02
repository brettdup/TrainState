#!/bin/zsh

set -u

cd "$(dirname "$0")" || exit 1

DEVICE_ID="00008120-000C618A11D8201E"
PROJECT="TrainState.xcodeproj"
SCHEME="TrainState"
BUNDLE_ID="brettduplessis.TrainState"
DERIVED_DATA="$PWD/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/Exercise Pal.app"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  build

BUILD_STATUS=$?

if [ "$BUILD_STATUS" -ne 0 ]; then
  echo
  echo "Build failed with status $BUILD_STATUS."
  echo "Press Return to close..."
  read
  return "$BUILD_STATUS" 2>/dev/null || exit "$BUILD_STATUS"
fi

if [ ! -d "$APP_PATH" ]; then
  echo
  echo "Could not find app at:"
  echo "$APP_PATH"
  echo
  echo "Available apps:"
  find "$DERIVED_DATA/Build/Products/Debug-iphoneos" -maxdepth 1 -name "*.app" -type d
  echo
  echo "Press Return to close..."
  read
  return 1 2>/dev/null || exit 1
fi

xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  "$APP_PATH"

INSTALL_STATUS=$?

if [ "$INSTALL_STATUS" -ne 0 ]; then
  echo
  echo "Install failed with status $INSTALL_STATUS."
  echo "Press Return to close..."
  read
  return "$INSTALL_STATUS" 2>/dev/null || exit "$INSTALL_STATUS"
fi

xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  "$BUNDLE_ID"

LAUNCH_STATUS=$?

echo
if [ "$LAUNCH_STATUS" -eq 0 ]; then
  echo "Done."
else
  echo "Launch failed with status $LAUNCH_STATUS."
fi

echo "Press Return to close..."
read

return "$LAUNCH_STATUS" 2>/dev/null || exit "$LAUNCH_STATUS"
