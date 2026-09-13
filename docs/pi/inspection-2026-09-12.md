# Pi Inspection: 2026-09-12

> **Historical record.** This is the read-only survey taken *before* the
> September 12 repair. The radio was stopped at the time. For today's state see
> [Pi overview](../pi-overview.md); the fixes that followed are in the
> [repair journal](repair-2026-09-12.md).

Read-only inspection through the existing `jcradio-pi` SSH alias. Observations
describe this session, not a guarantee of application or audio functionality.

## Scope and Method

- <details> <summary> <b>Scope and Method</b> </summary>

    - SSH host-key verification and non-interactive authentication succeeded.
    - No software installation, service changes, restarts, database tasks, or
      deliberate file writes on the Pi are authorized for this inspection.
    - SSH access and ordinary reads can still affect system logs or access times.
    - Record selected findings locally, not raw credentials, environment dumps,
      complete process arguments, or database contents.

  </details>

## Host Identity

- <details> <summary> <b>Host Identity</b> </summary>

    Observed at `2026-09-12T16:28:18-07:00` according to the Pi's clock.

    | Property | Observation |
    | --- | --- |
    | Hostname / SSH user | `raspberrypi` / `pi` (UID 1000) |
    | Hardware | Raspberry Pi 3 Model B Rev 1.2 |
    | OS | Raspbian GNU/Linux 9 (Stretch) |
    | Kernel | `4.19.66-v7+`, built August 15, 2019 |
    | Architecture | `armv7l`, Debian `armhf` |
    | Uptime at first check | Approximately 3 hours 51 minutes |

    Sources: `hostname`, `id`, `date -Is`, `uptime`, `uname -a`,
    `/etc/os-release`, `/proc/device-tree/model`, and
    `dpkg --print-architecture` over SSH. No privileged commands were used.

  </details>

## Owner Context and Runtime State

- <details> <summary> <b>Owner Context and Runtime State</b> </summary>

    Austin subsequently confirmed that the radio is stopped, recalled normally
    using `jcradio-start`, and believes forwarding is not set up on the new
    Xfinity network. Thus the stopped website is expected, not evidence of a
    newly discovered crash. Starting locally and forwarding internet traffic
    are separate operations; neither was performed.

    Observations span `16:28:18` through `16:31:48` PDT on September 12, 2026.
    Sources: systemd selected properties, process names without arguments,
    `ss -lnt`, and ALSA status files.

    | Component | Observation |
    | --- | --- |
    | Rails / Puma | No matching process or listener on configured port 3000 |
    | librespot | No matching process; configured loopback playback endpoint closed |
    | DarkIce | PID 652, root-owned, running with loopback capture open |
    | Icecast | PID 565, user `icecast2`, running; TCP 8000 listening |
    | SSH | TCP 10110 listening on IPv4 and IPv6; alias works |
    | No-IP | `noip2.service` enabled and running as `nobody`; successful updates not established |
    | Raspotify / Mopidy units | Disabled, inactive/dead |
    | DarkIce unit | Generated SysV unit, active/exited; `/etc/default/darkice` has `RUN=no` |
    | Icecast unit | Generated SysV unit, active/running; `/etc/default/icecast2` has `ENABLE=true` |
    | Certbot timer | Active/waiting, not proof of successful renewals |
    | Other services | Docker active; VNC and `raspidisp_server` failed; not diagnosed as radio dependencies |

    Only TCP ports 10110 and 8000 were listening at the final check, not
    22, 80, 443, or 3000. This is not a firewall/router audit.

  </details>

## Recovered Audio Pipeline

- <details> <summary> <b>Recovered Audio Pipeline</b> </summary>

    Configuration was read through explicit non-secret field selection, not
    copied wholesale. Credential-bearing launcher lines were withheld.

    | Stage | Inspected Configuration |
    | --- | --- |
    | Client | `/usr/bin/librespot`, name `JCRadio`, backend ALSA, bitrate 320 |
    | Playback device | `plughw:Loopback,1` |
    | Kernel module | `/etc/modules` includes `snd-aloop`; ALSA lists Loopback as card 1 |
    | DarkIce input | `/etc/darkice.cfg`: `plughw:Loopback,0`, 44100 Hz, 16-bit stereo |
    | Buffering | One second, unlimited duration, reconnect enabled |
    | Encoding | Constant-bitrate MP3 at 320 kbps |
    | Output | `localhost:8000`, mount `rapi.mp3`, source password present but withheld |
    | Default sound device | `/etc/asound.conf` and `/home/pi/.asoundrc` select card 0; radio commands override this explicitly |

    `/proc/asound/Loopback/pcm0c/sub0/status` reported RUNNING, owned by PID
    652. `/proc/asound/Loopback/pcm1p/sub0/status` reported closed.

    A GET of `http://127.0.0.1:8000/status-json.xsl` returned HTTP 200,
    Icecast 2.4.2, one `audio/mpeg` source at `/rapi.mp3`, 320 kbps, and zero
    current/peak listeners. Its advertised host `0.0.0.0` is not an address to
    give remote listeners. No audio was downloaded or analyzed. Silence is
    plausible without a loopback writer, but was not measured.

    `/etc/icecast2/icecast.xml` is service-owned, mode 0660, and unreadable by
    `pi`. The read was denied; no privilege escalation or alternate access was
    attempted. Full authentication, listener-limit, and Icecast settings remain
    unverified.

  </details>

## Startup Files and TLS

- <details> <summary> <b>Startup Files and TLS</b> </summary>

    These are inspected descriptions, not commands executed during this session:

    - `/etc/rc.local` attempts background librespot startup, writing output to
      `/home/pi/librespot.log`, and launches `/home/pi/darkice.sh`.
    - The DarkIce wrapper invokes `/usr/bin/darkice -c /etc/darkice.cfg`.
      Its observed ancestry includes privilege wrappers and runs as root;
      the regular DarkIce init script's `RUN=no` does not stop this separate path.
    - `/home/pi/.bashrc` defines `jcradio-start`, `jcradio-startstop`,
      `librespot-start`, `librespot-restart`, and `librespot-startstop`.
      `jcradio-stop` was not among the inspected definitions.
    - `jcradio-start` enters `/home/pi/jcradio` and runs daemonized `rails server`
      with an SSL bind at `0.0.0.0:3000`, using certificate paths under
      `/etc/letsencrypt/live/jcradio.ddns.net/`.
    - Stop-like functions contain force-kill operations. They are historical
      implementation details, not safe restart recommendations.
    - Shell profiles load RVM; its default points to Ruby 2.4.9. Profiles were
      read, not sourced. No Rails-specific systemd unit appeared in the inventory.
      `pi`'s crontab has no active entries; root cron was not inspected.

    The public certificate, read with `openssl x509`, is for `jcradio.ddns.net`,
    issued by Let's Encrypt R3, valid August 29, 2021, 19:16:06 GMT through
    **November 27, 2021, 19:16:05 GMT**. It is expired. Private keys were not
    read. Renewal failure was not diagnosed, and expiry is not proof of why a
    manually started website is currently stopped.

  </details>

## Network, Storage, and Clock

- <details> <summary> <b>Network, Storage, and Clock</b> </summary>

    | Property | Observation |
    | --- | --- |
    | Ethernet | Static `10.0.0.110/24`, metric 100 |
    | Wi-Fi | `10.0.0.145/24` observed, metric 200 |
    | Gateway | `10.0.0.1`, Ethernet preferred |
    | Wired DNS | `10.0.0.1` and `8.8.8.8` |
    | Root filesystem | ext4, 30 GB total, 7.2 GB used, 21 GB available |
    | Memory | 864 MiB reported, about 636 MiB available at first check |
    | Swap | 99 MiB, unused at first check |
    | Clock | America/Los_Angeles, NTP enabled/synchronized, no RTC reported |

    Wired settings agree with the static Ethernet entry in `/etc/dhcpcd.conf`.
    Both physical interfaces also have IPv6 addresses; global address values
    are omitted. Router rules, firewall policy, public DNS resolution, and
    external reachability were not tested or changed.

    Systemd/Icecast startup records report February 16, 2025, despite the
    current 2026 clock and under-four-hour initial uptime. Clock correction
    after boot is plausible; these timestamps do not prove continuous uptime
    since 2025. Old log dates need the same caution.

    The later [Xfinity guide](network-setup.md) explains its documented DHCP
    requirement, which may conflict with the current Pi-side static address.
    The gateway was later identified as an Xfinity router.

  </details>

## Application and Data

- <details> <summary> <b>Application and Data</b> </summary>

    | Item | Observation |
    | --- | --- |
    | Checkout | `/home/pi/jcradio`, branch `master` |
    | HEAD | `1a232fd6582b12fb460de2b11a329a5d183fc966` |
    | RVM install | `/home/pi/.rvm/rubies/ruby-2.4.9` |
    | Pi lockfile | Rails 4.2.8, Puma 4.3.5, RSpotify 2.9.2, omniauth-oauth2 1.3.1, SQLite gem 1.3.13, Bundler 1.17.3 |
    | Development database | 24,883,200 bytes, mtime June 28, 2024 |
    | Other database files | Test: 94,208 bytes; typo-named `devlopment.sqlite3`: zero bytes |
    | OAuth restore file | `/home/pi/jcradio/.nothingtoseehere.yml` exists; contents not read |

    Three files are uncommitted: sessions controller, sessions home view, and
    routes. Eight insertions and six deletions include changing the player action
    from `librespot_start` / `librespot-start` to `librespot_restart` /
    `librespot-restart`. Additional view lines were not analyzed. These changes
    were not copied, reverted, or incorporated into local application code.

    Git inspection disabled optional locks. No database was opened, queried,
    copied, or modified. This database is a possible recovery source, not yet
    confirmed as authoritative. A clean checkout would not preserve local edits.

  </details>

## Packages and Logs

- <details> <summary> <b>Packages and Logs</b> </summary>

    Selected installed package versions, not a full inventory:

    | Package | Version |
    | --- | --- |
    | Raspotify | `0.14.0~librespot.20200130T014147Z.3672214` |
    | DarkIce | `1.0.1-999~mp3+1`, custom MP3-capable build |
    | Icecast | `2.4.2-1+deb9u1` |
    | ALSA utilities | `1.1.3-1` |
    | Node.js | `8.11.1~dfsg-2~bpo9+1` |
    | FFmpeg | `7:3.2.14-1~deb9u1+rpt1` |
    | SQLite CLI | `3.16.2-5+deb9u1` |
    | Certbot | `0.28.0-1~deb9u2` |
    | OpenSSH server | `1:7.4p1-10+deb9u7` |

    Python 3.5 ran the read-only parsers with bytecode writes disabled; a separate
    Python 3.8 binary exists. Installation alone does not imply active use.

    Only diagnostic labels were returned from small log tails, not raw lines:

    - `/home/pi/librespot.log`: 70,905,769 bytes. The last 32 KiB contain seven
      panic lines with `unwrap`, `result.rs:1188:5`, error code 19, kind `Other`.
      Last recognized timestamp: `2025-02-17T02:37:23`. This is historical failure
      evidence, not a confirmed current root cause.
    - `/home/pi/jcradio/log/development.log`: 80,726,766 bytes. Tail contains
      error-level records; last recognized timestamp: `2024-07-06 22:06:22`.
      Individual application failures were not diagnosed.
    - `/var/log/icecast2/error.log`: 5,701 bytes, with warning records in the
      inspected tail. Rotated logs also exist.

  </details>

## Preservation and Open Items

- <details> <summary> <b>Preservation and Open Items (as of the inspection)</b> </summary>

    Most of these were resolved by the repair the same evening; see the
    [repair journal](repair-2026-09-12.md) and current [open items](../README.md#open-items).

    - No backup was made. Preserve database, Pi-only edits, launchers, TLS files,
      and credentials privately before repairs or redeployment.
    - Librespot launcher lines contain credential arguments. The launcher is
      mode 0755; `.bashrc`, OAuth restore YAML, and database are mode 0644.
      These permit other local users to read where directory access permits.
      Secret values were withheld; permissions and credentials were unchanged.
    - Exact player failure, present Spotify compatibility, protected Icecast
      settings, and the precise historical listening-tab workflow remain open.
    - Test local startup and TLS separately from outside access in a future
      approved session. No router changes, service starts, or renewals were made.

  </details>
