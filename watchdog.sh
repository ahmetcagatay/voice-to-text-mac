#!/bin/bash
# Hammerspoon External Watchdog
# Hammerspoon donmuşsa dışarıdan restart eder.
# launchd tarafından her 60 saniyede çalıştırılır.

HEARTBEAT="$HOME/.hammerspoon/.heartbeat"
LOG="/tmp/hammerspoon-watchdog.log"
MAX_HEARTBEAT_AGE=180  # 3 dk'dan eski heartbeat = sorun var

# Hammerspoon hiç çalışmıyorsa → başlat
if ! pgrep -xq "Hammerspoon"; then
    echo "$(date): Hammerspoon not running, starting..." >> "$LOG"
    open -a Hammerspoon
    exit 0
fi

# Heartbeat dosyası yoksa → henüz yeni başlamış olabilir, bekle
if [ ! -f "$HEARTBEAT" ]; then
    exit 0
fi

# Heartbeat yaşını kontrol et
LAST_BEAT=$(cat "$HEARTBEAT" 2>/dev/null)
NOW=$(date +%s)
AGE=$(( NOW - LAST_BEAT ))

if [ "$AGE" -gt "$MAX_HEARTBEAT_AGE" ]; then
    echo "$(date): Heartbeat stale (${AGE}s old), restarting Hammerspoon..." >> "$LOG"
    pkill -x Hammerspoon
    sleep 2
    open -a Hammerspoon
fi
