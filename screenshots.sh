#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Patrick Zwick

set -euo pipefail

out="fastlane/metadata/android/en-US/images"

website=""
while [ $# -gt 0 ]; do
  case "$1" in
    --website)
      website="$2"
      shift 2
      ;;
    *)
      echo "usage: $0 [--website DIR]" >&2
      exit 1
      ;;
  esac
done

adb wait-for-device
adb shell settings put secure accessibility_enabled 0
adb shell settings delete secure enabled_accessibility_services
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0900
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi hide -e mobile hide -e airplane hide -e satellite hide -e nosim hide
adb shell am broadcast -a com.android.systemui.demo -e command status -e volume hide -e bluetooth hide -e location hide -e alarm hide -e sync hide -e tty hide -e eri hide -e mute hide -e speakerphone hide
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
adb emu geo fix 2.3522 48.8566

for profile in \
  "phone 1080 1920 420 phoneScreenshots 1815 540 1194 540 826 0 0 540 1023" \
  "tablet7 1920 1080 240 sevenInchScreenshots 1020 120 308 960 465 429 257 960 423" \
  "tablet10 2560 1440 240 tenInchScreenshots 1380 120 308 1280 465 429 257 1280 610"; do
  set -- $profile
  w=$2
  h=$3
  density=$4
  dir="$out/$5"
  nav_y=$6
  trip_x=$7
  trip_y=$8
  entry_x=$9
  entry_y=${10}
  scroll_from=${11}
  scroll_to=${12}
  card_x=${13}
  card_y=${14}

  adb shell wm size "${w}x${h}"
  adb shell wm density "$density"
  adb shell am force-stop xyz.journai.app
  adb shell am start -n xyz.journai.app/.MainActivity
  sleep 8

  mkdir -p "$dir"
  adb exec-out screencap -p > "$dir/0.png"

  adb shell input tap $((3 * w / 8)) "$nav_y"
  sleep 3
  adb exec-out screencap -p > "$dir/1.png"

  adb shell input tap "$trip_x" "$trip_y"
  sleep 6
  adb exec-out screencap -p > "$dir/2.png"

  adb shell input tap "$entry_x" "$entry_y"
  sleep 6
  adb exec-out screencap -p > "$dir/3.png"

  adb shell input keyevent 4
  sleep 1
  adb shell input keyevent 4
  sleep 1
  adb shell input tap $((w / 8)) "$nav_y"
  sleep 3
  if [ "$scroll_from" != "0" ]; then
    adb shell input swipe $((w / 2)) "$scroll_from" $((w / 2)) "$scroll_to" 600
    sleep 1
  fi
  adb shell input tap "$card_x" "$card_y"
  sleep 6
  adb exec-out screencap -p > "$dir/4.png"
done

adb shell wm size reset
adb shell wm density reset
adb shell am broadcast -a com.android.systemui.demo -e command exit
adb shell am start -n xyz.journai.app/.MainActivity

if [ -n "$website" ]; then
  mkdir -p "$website"
  for i in 0 1 2 3 4; do
    magick "$out/phoneScreenshots/$i.png" -resize 450x -quality 80 "$website/$i.webp"
  done
fi
