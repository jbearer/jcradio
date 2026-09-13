#!/usr/bin/env bash
set -euo pipefail
umask 077

backup="$HOME/jcradio-recovery/2026-09-12"
incoming="$HOME/jcradio-recovery/incoming-2026-09-12"
release="$HOME/.local/share/jcradio-player/raspotify-0.48.2"

[[ ! -e "$release" ]] || { printf '%s\n' 'Player release already exists; refusing to overwrite.' >&2; exit 1; }
[[ ! -e "$HOME/.local/bin/librespot-current" ]] || { printf '%s\n' 'Player wrapper already exists; refusing to overwrite.' >&2; exit 1; }
command -v sqlite3 >/dev/null
printf '%s  %s\n' 'f92e297a024c320ba37e908fb5cbfe7da053b6f97d11f945f367b87840d2f4c3' "$incoming/player-0.48.2-armhf.tar.gz" | sha256sum --check

install -d -m 700 "$backup"
for source in /usr/bin/librespot "$HOME/.bashrc" /etc/rc.local /etc/default/raspotify; do
    [[ -r "$source" ]] || continue
    destination="$backup/$(basename "$source").original"
    [[ -e "$destination" ]] || cp -p "$source" "$destination"
    chmod 600 "$destination"
done
for relative in config/initializers/omniauth.rb app/models/station.rb app/controllers/sessions_controller.rb; do
    destination="$backup/source/$relative"
    install -d -m 700 "$(dirname "$destination")"
    [[ -e "$destination" ]] || cp -p "$HOME/jcradio/$relative" "$destination"
    chmod 600 "$destination"
done
if [[ -f "$HOME/jcradio/db/development.sqlite3" && ! -e "$backup/development.sqlite3" ]]; then
    sqlite3 "$HOME/jcradio/db/development.sqlite3" ".backup '$backup/development.sqlite3'"
    chmod 600 "$backup/development.sqlite3"
fi
if [[ -f "$HOME/jcradio/.nothingtoseehere.yml" && ! -e "$backup/radio-oauth.yml" ]]; then
    cp -p "$HOME/jcradio/.nothingtoseehere.yml" "$backup/radio-oauth.yml"
    chmod 600 "$backup/radio-oauth.yml"
fi
sha256sum /usr/bin/librespot "$backup/librespot.original"

install -d -m 700 "$release"
tar --no-same-owner -xzf "$incoming/player-0.48.2-armhf.tar.gz" -C "$release"
install -d "$HOME/.local/bin"
install -m 755 "$incoming/librespot-current" "$HOME/.local/bin/librespot-current"
"$HOME/.local/bin/librespot-current" --version
