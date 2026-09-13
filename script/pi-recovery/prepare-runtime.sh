#!/usr/bin/env bash
set -euo pipefail

cd /work
dpkg --add-architecture armhf
apt-get update
mkdir -p runtime-debs
cd runtime-debs
apt-get download libc6:armhf
cd /work

mkdir -p player-stage
install -m 755 raspotify-extracted/usr/bin/librespot player-stage/librespot
for package in runtime-debs/libc6_*_armhf.deb; do
    dpkg-deb --extract "$package" player-stage/runtime
    sha256sum "$package"
done
sha256sum player-stage/librespot
tar -C player-stage -czf player-0.48.2-armhf.tar.gz .
sha256sum player-0.48.2-armhf.tar.gz
