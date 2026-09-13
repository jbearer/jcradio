#!/usr/bin/env bash
set -euo pipefail
umask 077

state="$HOME/.local/state/jcradio-player"
install -d -m 700 "$state"
exec "$HOME/.local/bin/librespot-current" \
    --name JCRadio \
    --backend alsa \
    --device plughw:Loopback,1 \
    --bitrate 320 \
    --enable-volume-normalisation \
    --volume-ctrl linear \
    --initial-volume 100 \
    --system-cache "$state" \
    --disable-audio-cache \
    "$@" >> "$state/player.log" 2>&1
