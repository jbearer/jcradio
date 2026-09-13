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
    | Website | Rails running as `pi`, HTTPS on `0.0.0.0:3000`, started by `jcradio-start`; checkout `atc/dev`, clean tree |
    | Player | librespot 0.8.0 running as the enabled `jcradio-player` systemd service, authenticated as JC Radio, device `JCRadio` |
    | Encoder / stream | DarkIce running; Icecast serving `/rapi.mp3` at 320 kbps MP3; 1 listener connected at check time, peak 3 |
    | Database | `db/development.sqlite3`, about 25 MB, written to today; live history |
    | HTTPS | Certificate for `jcradio.ddns.net` **expired 2021-11-27**; browsers need an override |
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
    | OS | Raspbian 9 Stretch, kernel 4.19.66-v7+, glibc 2.24 |
    | Resources | 864 MiB RAM; 30 GB root filesystem, 21 GB free |
    | Web runtime | RVM Ruby 2.4.9, Rails 4.2.8, Puma 4.3.5 |
    | Player | Raspotify 0.48.2's librespot 0.8.0 under `~/.local/share/jcradio-player`, run through a private Debian Bookworm glibc loader (`~/.local/bin/librespot-current`) because the system glibc is too old |
    | Player service | `/etc/systemd/system/jcradio-player.service`, identical to [the repo copy](../script/pi-recovery/jcradio-player.service); credentials cached in `~/.local/state/jcradio-player` |
    | Website launcher | `jcradio-start` shell function in `/home/pi/.bashrc`: daemonized `rails server` with TLS, PID in `tmp/pids/server.pid`; no systemd unit |
    | Audio boot path | `/etc/rc.local` launches the DarkIce wrapper (and the legacy librespot, see below); `/etc/modules` loads `snd-aloop` |
    | Legacy player | Original `/usr/bin/librespot` (2020) untouched; `raspotify.service` disabled; `.bashrc` still defines `librespot-start`/`librespot-restart` for it |
    | DDNS | `noip2.service` enabled |

    **Legacy boot conflict:** `/etc/rc.local` still starts the 2020 librespot
    with password login, which Spotify no longer accepts, so it exits shortly
    after boot. It uses the same device name `JCRadio`. Remove that line (needs
    `sudo`) when convenient; until then it is harmless noise in
    `/home/pi/librespot.log`.

    After a reboot the player, encoder, and stream come back on their own; the
    website does not. Log in and run `jcradio-start`.

  </details>

## Local Versus Internet Access

- <details> <summary> <b>Local Versus Internet Access</b> </summary>

    Wired address `10.0.0.110` (static, preferred), Wi-Fi `10.0.0.145`, gateway
    `10.0.0.1`. Rails binds `0.0.0.0:3000` and Icecast `:8000`, so LAN access
    needs no router change. Internet access needs TCP 3000 and 8000 forwarded
    to the Pi; TCP 10110 is SSH and is optional. DDNS currently resolves to the
    home's public address.

    Whether the Xfinity gateway forwards those ports today has not been tested
    from outside the LAN. Follow the [network guide](pi/network-setup.md) to
    check and, if needed, add rules. The expired certificate is a separate
    issue: it does not block TCP reachability, but every browser will warn.

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
