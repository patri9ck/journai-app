#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Patrick Zwick

set -euo pipefail

PACKAGE="xyz.journai.app"
OUTPUT_DIR="build/screenshots"
RAW_DIR="$OUTPUT_DIR/raw"
CONFIG="build/screenshot_config.json"
LANGS=(en de)
SCREENSHOT_NAMES=(01_dashboard 02_emergency_card 03_full_map 04_country_info 05_vaccinations 06_entry_check 07_memories 08_stamp_book 09_trip)

declare -A LOCALE_MAP=(
  [en]="en-US"
  [de]="de-DE"
)

command -v adb >/dev/null 2>&1 || { echo "adb not found"; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "flutter not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found"; exit 1; }

if command -v magick >/dev/null 2>&1; then
  MAGICK=(magick)
elif command -v convert >/dev/null 2>&1; then
  MAGICK=(convert)
else
  echo "ImageMagick not found"
  exit 1
fi

DEVICE=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')
[ -n "$DEVICE" ] || { echo "No device connected"; exit 1; }
echo "Device: $DEVICE"

rm -rf "$OUTPUT_DIR"
mkdir -p "$RAW_DIR"

SOURCE_CONFIG="config.json"
[ -f "$SOURCE_CONFIG" ] || SOURCE_CONFIG="config.dev.json"

python3 - "$SOURCE_CONFIG" "$CONFIG" <<'EOF'
import json
import sys

config = json.load(open(sys.argv[1]))
config["BASE_URL"] = "http://127.0.0.1:9/"
json.dump(config, open(sys.argv[2], "w"))
EOF

restore_device() {
  adb -s "$DEVICE" shell wm size reset || true
  adb -s "$DEVICE" shell cmd uimode night no || true

  for SETTING in window_animation_scale transition_animation_scale animator_duration_scale; do
    adb -s "$DEVICE" shell settings put global "$SETTING" 1 || true
  done
}

trap restore_device EXIT

for SETTING in window_animation_scale transition_animation_scale animator_duration_scale; do
  adb -s "$DEVICE" shell settings put global "$SETTING" 0
done

adb -s "$DEVICE" shell wm size reset
adb -s "$DEVICE" shell cmd uimode night no

missing_screenshots() {
  local DIRECTORY="$1"
  local MISSING=0

  for LANG in "${LANGS[@]}"; do
    for NAME in "${SCREENSHOT_NAMES[@]}"; do
      [ -f "$DIRECTORY/$LANG/$NAME.png" ] || MISSING=$((MISSING + 1))
    done
  done

  echo "$MISSING"
}

capture() {
  local TYPE="$1"
  local MODE="$2"
  local DIRECTORY="$RAW_DIR/$TYPE/$MODE"

  if [ "$MODE" = "dark" ]; then
    adb -s "$DEVICE" shell cmd uimode night yes
  else
    adb -s "$DEVICE" shell cmd uimode night no
  fi

  sleep 1

  for ATTEMPT in 1 2; do
    echo "Capturing $TYPE $MODE (attempt $ATTEMPT)..."

    rm -rf "$DIRECTORY"
    adb -s "$DEVICE" uninstall "$PACKAGE" >/dev/null 2>&1 || true

    SCREENSHOT_OUTPUT="$DIRECTORY" flutter drive \
      --driver=test_driver/screenshot_driver.dart \
      --target=integration_test/screenshot_test.dart \
      --dart-define-from-file="$CONFIG" \
      -d "$DEVICE" || echo "flutter drive failed for $TYPE $MODE"

    if [ "$(missing_screenshots "$DIRECTORY")" -eq 0 ]; then
      return
    fi
  done
}

capture phone light
capture phone dark

adb -s "$DEVICE" shell wm size 1280x800
sleep 2
capture 7inch light

adb -s "$DEVICE" shell wm size 1920x1200
sleep 2
capture 10inch light

restore_device

to_jpg() {
  local SOURCE="$1"
  local TARGET="$2"
  shift 2

  [ -f "$SOURCE" ] || return 0

  mkdir -p "$(dirname "$TARGET")"
  "${MAGICK[@]}" "$SOURCE" "$@" -strip -background white -flatten -quality 85 "$TARGET"
}

for LANG in "${LANGS[@]}"; do
  LOCALE="${LOCALE_MAP[$LANG]}"
  NUMBER=1

  for NAME in "${SCREENSHOT_NAMES[@]}"; do
    to_jpg "$RAW_DIR/phone/light/$LANG/$NAME.png" "$OUTPUT_DIR/fastlane/$LOCALE/images/phoneScreenshots/$NUMBER.jpg"
    to_jpg "$RAW_DIR/7inch/light/$LANG/$NAME.png" "$OUTPUT_DIR/fastlane/$LOCALE/images/sevenInchScreenshots/$NUMBER.jpg"
    to_jpg "$RAW_DIR/10inch/light/$LANG/$NAME.png" "$OUTPUT_DIR/fastlane/$LOCALE/images/tenInchScreenshots/$NUMBER.jpg"
    to_jpg "$RAW_DIR/phone/light/$LANG/$NAME.png" "$OUTPUT_DIR/website/$LANG/light/$NUMBER.jpg" -resize 540x
    to_jpg "$RAW_DIR/phone/dark/$LANG/$NAME.png" "$OUTPUT_DIR/website/$LANG/dark/$NUMBER.jpg" -resize 540x
    NUMBER=$((NUMBER + 1))
  done
done

MISSING_TOTAL=0

for TYPE_MODE in phone/light phone/dark 7inch/light 10inch/light; do
  for LANG in "${LANGS[@]}"; do
    for NAME in "${SCREENSHOT_NAMES[@]}"; do
      if [ ! -f "$RAW_DIR/$TYPE_MODE/$LANG/$NAME.png" ]; then
        echo "Missing: $TYPE_MODE $LANG $NAME"
        MISSING_TOTAL=$((MISSING_TOTAL + 1))
      fi
    done
  done
done

rm -rf "$RAW_DIR"

echo "Screenshots in $OUTPUT_DIR/fastlane and $OUTPUT_DIR/website"

[ "$MISSING_TOTAL" -eq 0 ] || exit 1
