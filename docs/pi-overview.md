# Raspberry Pi Overview

The Pi hosts **the Rails website for the music game** and **a separate audio
pipeline that turns Spotify playback into a shared MP3 stream**. A No-IP
client keeps `jcradio.ddns.net` pointed at the home connection.

Facts on this page were checked on the Pi on **2026-09-13**, after the
September 12 repair. For commands, see [operating the Pi](operations.md).
The dated records that led here are under [Pi records](pi/README.md).

## Current State

- <details open> <summary> <b>Current State</b> </summary>

    | Piece | State |
    | --- | --- |
    | Website | Rails running as `pi`, HTTPS on `0.0.0.0:3000`, as the enabled `jcradio-web` systemd service; checkout `atc/dev`, clean tree |
    | Player | librespot 0.8.0 running as the enabled `jcradio-player` systemd service, authenticated as JC Radio, device `JCRadio` |
    | Encoder / stream | DarkIce running; Icecast serving `/rapi.mp3` at 320 kbps MP3; 1 listener connected at check time, peak 3 |
    | Database | `db/development.sqlite3`, about 25 MB, written to today; live history |
    | HTTPS | Certificate for `jcradio.ddns.net` renewed 2026-09-13 (standalone HTTP-01), valid to **2026-12-12**; a certbot deploy hook runs `jcradio-restart` on renewal |
    | OS packages | Stretch fully upgraded from the frozen `legacy.raspbian.org` archive on 2026-09-13 (610 packages) and rebooted; DarkIce is now Debian `1.3-0.1` and came up streaming. See the [post-upgrade inspection](pi/inspection-2026-09-13.md) |
    | DDNS | `jcradio.ddns.net` resolves to the home's current public IPv4 |
    | Router | Xfinity gateway (`Server: Xfinity Broadband Router Server` on `10.0.0.1`); forwarding rules not inspected |
    | Tests | `bin/rake test` on the Pi: 24 runs, 90 assertions, green |

    The player idles between tracks; when the queue runs out, the loopback
    playback device closes and the stream carries silence until the next song
    is added. That is normal, not a fault.

  </details>

## How It Connects

- <details> <summary> <b>How It Connects</b> </summary>

    ```mermaid
    flowchart TD
        Browser[Queue and game browser] -->|HTTPS port 3000|Rails[Rails and Puma]
        Rails <-->|Selections and application data|DB[(SQLite on SD card)]
        Rails -->|Search and playback control|Spotify[Spotify APIs]
        Spotify -->|Shared account playback|Player[librespot 0.8.0 systemd service]
        Player -->|Playback: Loopback,1|Loopback[ALSA loopback]
        Loopback -->|Capture: Loopback,0|DarkIce[DarkIce MP3 encoder]
        DarkIce -->|320 kbps to localhost:8000|Icecast[Icecast /rapi.mp3]
        Icecast -->|HTTP stream|Listener[Listening tab]
    ```

    DarkIce captures stereo, 16-bit, 44.1 kHz audio and produces constant-bitrate
    MP3. The stream is separate from Rails' live title/progress updates and
    from Spotify previews in search results.

  </details>

## Host and Startup

- <details> <summary> <b>Host and Startup</b> </summary>

    | Area | Setup |
    | --- | --- |
    | Hardware | Raspberry Pi 3 Model B Rev 1.2, 32-bit ARM (`armv7l`) |
    | OS | Raspbian 9 Stretch (end-of-life; packages from `legacy.raspbian.org`), kernel 4.19.66-v7+, glibc 2.24 |
    | Resources | 864 MiB RAM; 30 GB root filesystem, 21 GB free |
    | Web runtime | RVM Ruby 2.4.9, Rails 4.2.8, Puma 4.3.5 |
    | Player | Raspotify 0.48.2's librespot 0.8.0 under `~/.local/share/jcradio-player`, run through a private Debian Bookworm glibc loader (`~/.local/bin/librespot-current`) because the system glibc is too old |
    | Player service | `/etc/systemd/system/jcradio-player.service`, identical to [the repo copy](../script/pi-recovery/jcradio-player.service); credentials cached in `~/.local/state/jcradio-player` |
    | Website service | `/etc/systemd/system/jcradio-web.service`, identical to [the repo copy](../script/pi-recovery/jcradio-web.service): foreground `rails server` with TLS, Spotify credentials from `~/.config/jcradio/env`; `jcradio-start` / `jcradio-stop` / `jcradio-restart` in `.bashrc` wrap `systemctl` |
    | TLS renewal | `certbot.timer` (twice daily, `standalone` HTTP-01 on port 80); `/etc/letsencrypt/renewal-hooks/deploy/jcradio-restart-rails.sh` runs `jcradio-restart` after a renewal so Puma reloads the files; copy in [the repo](../script/pi-recovery/certbot-deploy-jcradio.sh) |
    | Audio boot path | `/etc/rc.local` launches the DarkIce wrapper; `/etc/modules` loads `snd-aloop` |
    | Legacy player | Original `/usr/bin/librespot` (2020) still on disk but no longer launched; `raspotify.service` disabled; legacy `.bashrc` functions and the `rc.local` line were removed 2026-09-13 |
    | DDNS | `noip2.service` enabled |

    After a reboot the website, player, encoder, and stream all come back on
    their own (website autostart added 2026-09-13).

  </details>

## Local Versus Internet Access

- <details> <summary> <b>Local Versus Internet Access</b> </summary>

    Wired address `10.0.0.110` (static, preferred), Wi-Fi `10.0.0.145`, gateway
    `10.0.0.1`. Rails binds `0.0.0.0:3000` and Icecast `:8000`, so LAN access
    needs no router change. Internet access needs TCP 3000 and 8000 forwarded
    to the Pi; TCP 80 must stay forwarded for certificate renewal; TCP 10110
    is SSH and is optional. DDNS currently resolves to the home's public
    address.

    Whether the Xfinity gateway forwards those ports today has not been tested
    from outside the LAN. Follow the [network guide](pi/network-setup.md) to
    check and, if needed, add rules. The successful standalone certificate
    renewal on 2026-09-13 shows TCP 80 already reaches the Pi from outside;
    3000 and 8000 remain untested.

  </details>

## Preserve Before Changing

- <details> <summary> <b>Preserve Before Changing</b> </summary>

    - Pre-repair backups (database, OAuth file, original binary, launchers,
      source) are in `~/jcradio-recovery/2026-09-12`; see
      [backups](operations.md#backups) for taking a new one.
    - `~/jcradio/.nothingtoseehere.yml` and
      `~/.local/state/jcradio-player/credentials.json` are credentials. Keep
      them out of the repository and chat.
    - `.bashrc` launcher functions still contain the legacy player's password
      arguments. Rotate that password if it has not been, and do not paste
      those functions anywhere.
    - Cloud planning must cover audio delivery and private data as well as
      Rails. See [future hosting](hosting.md).

  </details>
