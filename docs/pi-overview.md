# Raspberry Pi Overview

The Pi hosts **the Rails website for the music game** and **a separate audio
pipeline that turns Spotify playback into a shared MP3 stream**. A No-IP
client supports the historical DDNS setup.

This page combines read-only SSH observations from **September 12, 2026** with
owner clarification. No services, files, or configuration were deliberately
changed on the Pi. See [inspection evidence](pi/inspection-2026-09-12.md) and
[Xfinity network setup](pi/network-setup.md).

## Current State

- <details open> <summary> <b>Current State</b> </summary>

    **Owner context:** the radio is stopped, normally started with
    `jcradio-start`, and port forwarding is believed not to be configured.

    | Piece | Observed State |
    | --- | --- |
    | Website | No Rails/Puma process or port-3000 listener; consistent with owner context |
    | Player | No librespot process; loopback playback endpoint closed |
    | Encoder / stream | DarkIce running; Icecast reports `/rapi.mp3`, 320 kbps MP3, zero listeners |
    | HTTPS | Configured public certificate expired November 27, 2021 |
    | SSH | Existing `jcradio-pi` alias works; server listens on TCP 10110 |
    | Network | Ethernet and Wi-Fi connected; Ethernet preferred; DDNS updater running |

    The expected stopped website is not evidence of an unexpected crash. An
    active Icecast source does not prove that music is audible. Neither local
    startup nor end-to-end listening was tested.

  </details>

## How It Connects

- <details> <summary> <b>How It Connects</b> </summary>

    ```mermaid
    flowchart TD
        Browser[Queue and game browser] -->|Configured HTTPS port 3000|Rails[Rails and Puma]
        Rails <-->|Selections and application data|DB[(SQLite on SD card)]
        Rails -->|Search and playback control|Spotify[Spotify APIs]
        Spotify -->|Shared account playback|Player[librespot]
        Player -->|Playback: Loopback,1|Loopback[ALSA loopback]
        Loopback -->|Capture: Loopback,0|DarkIce[DarkIce MP3 encoder]
        DarkIce -->|320 kbps to localhost:8000|Icecast[Icecast /rapi.mp3]
        Icecast -.->|HTTP stream; historical workflow|Listener[Listening tab]
    ```

    This is configured wiring, not a current end-to-end test. DarkIce captures
    stereo, 16-bit, 44.1 kHz audio and produces constant-bitrate MP3. The stream
    is separate from Rails' live title/progress updates and Spotify previews.

  </details>

## Host and Startup

- <details> <summary> <b>Host and Startup</b> </summary>

    | Area | Recovered Setup |
    | --- | --- |
    | Hardware | Raspberry Pi 3 Model B Rev 1.2, 32-bit ARM |
    | OS | Raspbian 9 Stretch, kernel 4.19.66-v7+ |
    | Resources | 864 MiB reported RAM; 30 GB root filesystem, 21 GB available at inspection |
    | Web runtime | RVM Ruby 2.4.9, Rails 4.2.8, Puma 4.3.5 |
    | Audio runtime | Early-2020 Raspotify/librespot, custom DarkIce MP3 build, Icecast 2.4.2 |
    | Website launcher | Shell function in `/home/pi/.bashrc`; daemonized Rails with TLS on port 3000 |
    | Audio boot path | `/etc/rc.local` attempts librespot and a DarkIce wrapper; `/etc/modules` loads `snd-aloop` |
    | DDNS | Enabled `noip2.service` |

    There is no established single supervisor for the whole radio. The normal
    Raspotify unit is disabled; no Rails-specific systemd unit was found.
    The inspected user crontab has no active entries; root cron was not inspected.

    The old README's `jcradio-stop` was not among the inspected shell definitions.
    Stop-like functions contain force-kill operations; treat them as historical
    code, not a safe recovery recipe.

  </details>

## Local Versus Internet Access

- <details> <summary> <b>Local Versus Internet Access</b> </summary>

    The observed wired address is `10.0.0.110`, preferred over Wi-Fi
    `10.0.0.145`. `jcradio-start` binds locally to `0.0.0.0:3000` using HTTPS.
    Router port forwarding is not needed for that bind or ordinary LAN access;
    it is needed for direct inbound internet access through the router.

    The legacy setup would forward TCP 3000 for the website and TCP 8000 for
    Icecast, with TCP 10110 optional for remote SSH, not listeners. Xfinity's
    app requires a DHCP IPv4 device, which may conflict with the Pi-side static
    Ethernet configuration. Follow the [network guide](pi/network-setup.md)
    before changing the address or opening ports.

    The expired certificate is a separate browser-validation issue. Router
    rules, DDNS resolution, external access, and TLS renewal were not tested.

  </details>

## Preserve Before Restarting or Moving

- <details> <summary> <b>Preserve Before Restarting or Moving</b> </summary>

    `/home/pi/jcradio` is on `master` at
    `1a232fd6582b12fb460de2b11a329a5d183fc966`, with three uncommitted files
    changing the player control from **start** to **restart**. Preserve these
    before pulling or redeploying. The development database is about 25 MB;
    it was not opened, backed up, or confirmed as the authoritative history.

    Launchers contain credential arguments. Some sensitive files have permissive
    local read modes. Preserve originals privately, never as unredacted repository
    copies. The old player log contains panic evidence, not a confirmed explanation
    for its current stopped state.

    A later approved session can test local startup and TLS, then outside access.
    Cloud planning must cover audio delivery and private data as well as Rails.
    See [Pi evidence](pi/README.md), [recovery](operations.md), and
    [future hosting](hosting.md).

  </details>
