# Pi Inspection: 2026-09-13 (after `apt upgrade`)

> **Historical record.** Read-only survey taken about ten minutes after the
> owner ran `sudo apt update` and `sudo apt upgrade` on the Stretch install.
> Compare with the [pre-repair inspection](inspection-2026-09-12.md). For the
> current state see [Pi overview](../pi-overview.md); for commands see
> [operating the Pi](../operations.md).

Inspection through the existing `jcradio-pi` SSH alias between `13:45` and
`13:52` PDT. Nothing was installed, restarted, or written on the Pi. Process
names were listed without arguments; no credential files or launcher bodies
were read.

## What Changed Today

- <details open> <summary> <b>What Changed Today</b> </summary>

    | Change | Observation |
    | --- | --- |
    | APT sources | Raspbian moved to `legacy.raspbian.org` (the original and `archive.raspbian.org` return 404 for Stretch); `mopidy.list` renamed to `mopidy.list.disabled`; Raspberry Pi, Docker, UV4L, and Raspotify sources unchanged |
    | `apt upgrade` | `13:16:41`–`13:37:59` PDT, **610 packages upgraded**, zero installed or removed; `dpkg --audit` clean; no `.dpkg-dist` / `.dpkg-old` files under `/etc` from today |
    | Reboot flag | `/var/run/reboot-required` is present (`libc6`, `systemd`, `udev`, `dbus`, `libssl1.1` among the upgrades); the kernel package is unchanged (`1.20190819~stretch-1`, running `4.19.66-v7+`) |
    | DarkIce | Package replaced: custom `1.0.1-999~mp3+1` (2016 binary) is now Debian `1.3-0.1`. The new `/usr/bin/darkice` links `libmp3lame`, `libtwolame`, `libvorbis`, and `libopus`. `/etc/darkice.cfg` (2020) and `/home/pi/darkice.sh` (2020) were not touched |
    | Running DarkIce | PID 652 still executes the **deleted old binary** (`/proc/652/exe` -> `/usr/bin/darkice (deleted)`), so the 1.3 build has not yet encoded anything |
    | TLS certificate | Renewed `13:38` PDT via certbot `standalone`; valid **until 2026-12-12 19:39:42 GMT**. Rails on `:3000` already serves it |
    | Rails | Restarted at `13:40:07` PDT by the new certbot deploy hook `/etc/letsencrypt/renewal-hooks/deploy/jcradio-restart-rails.sh`, which runs `jcradio-restart` as `pi` |
    | Git | `1:2.11.0-3+deb9u7`, still Git 2.11.0 (no `git restore`); owner chose to keep it |
    | Still upgradable | Only `raspotify` (`0.48.2~librespot.v0.8.0-9c7d756`), held back by `apt upgrade`. Leave it: its Bookworm build needs a newer glibc, and the private copy under `~/.local/share/jcradio-player` already runs |

    The 610-package list is in `/var/log/apt/history.log` (last block). Notable
    entries: `apt`/`dpkg`, `libc6 2.24-11+deb9u4`, `systemd 232-25+deb9u14`,
    `openssl`/`libssl1.1 1.1.0l-1~deb9u6`, `sqlite3`/`libsqlite3-0 3.16.2-5+deb9u3`,
    `ffmpeg 7:3.2.18`, `certbot 0.28.0-1~deb9u3`, `curl 7.52.1-5+deb9u16`,
    `sudo`, `rsyslog`, `docker-ce 19.03.15`, `uv4l-*`, `vlc 3.0.12`, `git`.

  </details>

## Host Identity

- <details> <summary> <b>Host Identity</b> </summary>

    | Property | Observation |
    | --- | --- |
    | Clock | `2026-09-13T13:45:23-07:00`, uptime 1 day 1 h 8 min (no reboot since the upgrade) |
    | Hardware / OS | Raspberry Pi 3 Model B Rev 1.2, Raspbian 9 (Stretch), `armhf`, glibc `2.24-11+deb9u4` |
    | Kernel | `4.19.66-v7+`; `/boot/kernel7.img` dated 2020-04-18, unchanged |
    | Root filesystem | 30 GB, 7.4 GB used, 21 GB free (27 %) |
    | Memory | 864 MiB total, 546 MiB available; swap 99 MiB, **42 MiB in use** (was 0 on the 12th) |
    | Python | `python3` is 3.5.3 |

  </details>

## Services and Processes

- <details> <summary> <b>Services and Processes</b> </summary>

    | Unit | State |
    | --- | --- |
    | `jcradio-player` | active/running, enabled; MainPID 11834 (the glibc loader), started `11:12:04` PDT, before the upgrade |
    | `darkice` (generated) | active/exited; the actual encoder is root PID 652 from `/etc/rc.local`, up since boot |
    | `icecast2` (generated) | active/running, PID 565 |
    | `noip2` | active/running as `nobody`, PID 358 |
    | `ssh`, `docker` | active/running, enabled |
    | `certbot.timer` | active/waiting; last trigger `13:16:47` PDT |
    | `raspotify` | inactive/dead, disabled (unchanged) |
    | Failed units | `certbot.service` (exit 1 at `13:16:47`, during the upgrade), `raspidisp_server.service`, `vncserver-x11-serviced.service` |

    The `certbot.service` failure predates the successful `13:38` renewal; the
    renewal log ends with `no renewal failures`. The unit stays in `failed`
    until its next timer run or a manual `systemctl reset-failed`.

    Rails: `ruby` PID 17049 (Puma) started `13:40:07` PDT, `tmp/pids/server.pid`
    matches, `https://127.0.0.1:3000/` answers HTTP 200. Login-shell Ruby is
    RVM `2.4.9p362` with Bundler `1.17.3`; `ruby` is not on the non-login PATH.

    Listening TCP: `3000` (Rails), `8000` (Icecast), `10110` (SSH), and an
    ephemeral `36401`. Ports 22, 80, and 443 are closed as before; the
    standalone renewal opened 80 only transiently.

  </details>

## Audio Pipeline and Stream

- <details> <summary> <b>Audio Pipeline and Stream</b> </summary>

    | Stage | Observation |
    | --- | --- |
    | Player | `check-player.rb`: librespot `0.8.0 9c7d7561`, `Authenticated`, ALSA backend, one `ERROR` marker (the known `spirc 400` pattern); log 19,887 bytes |
    | Loopback | `pcm0c` RUNNING (DarkIce capturing); `pcm1p` closed (player idle) |
    | DarkIce config | `plughw:Loopback,0`, 44100 Hz, 16-bit stereo, CBR MP3 320 kbps, `localhost:8000/rapi.mp3`; unchanged |
    | Icecast | 2.4.2, mount `/rapi.mp3` at 320 kbps, 1 listener, peak 3 |
    | Stream (from laptop) | 6 s of `http://jcradio.ddns.net:8000/rapi.mp3`: MP3 stereo 44.1 kHz 320 kbps, mean/peak `-91.0 dB` (silence, queue empty) |

    Silence with `pcm1p` closed is the normal idle state, not a fault. The
    stream was not exercised with a queued song during this inspection.

  </details>

## Application, Data, and Network

- <details> <summary> <b>Application, Data, and Network</b> </summary>

    | Item | Observation |
    | --- | --- |
    | Checkout | `/home/pi/jcradio`, branch `atc/dev` tracking `origin/atc/dev`, clean tree |
    | HEAD | `f4f8c92` "Handful of fixes" (2026-09-13 12:46 PDT) |
    | Development DB | 25,022,464 bytes, mtime `13:03` PDT, `journal_mode=wal` |
    | Development log | 94.4 MB, written at inspection time |
    | `/etc/rc.local` | mtime `12:53` PDT (librespot line removed by the owner); still launches `darkice.sh` |
    | Legacy `/usr/bin/librespot` | 2020-02-16 binary, unchanged; `raspotify` package still `0.14.0` |
    | Addresses | `eth0 10.0.0.110/24` (default route, metric 100), `wlan0 10.0.0.145/24` (metric 200), `docker0 172.17.0.1/16` |
    | DDNS | `jcradio.ddns.net` resolves to the current public IPv4 (matches `api.ipify.org`) |
    | Certificate on disk | `/etc/letsencrypt/live/jcradio.ddns.net/cert.pem` written `13:38` PDT; `notBefore` 2026-09-13 19:39:43 GMT, `notAfter` 2026-12-12 19:39:42 GMT |
    | Renewal config | `authenticator = standalone`; deploy hook `jcradio-restart-rails.sh` appends to `/var/log/jcradio-cert-deploy.log` and runs `jcradio-restart`; no pre/post hooks |

    Inference: a successful HTTP-01 standalone renewal means TCP 80 reached the
    Pi from the internet at `13:38`, so the Xfinity gateway forwards at least
    that port. Outside reachability of 3000 and 8000 was still not tested.

  </details>

## Follow-ups

- <details> <summary> <b>Follow-ups</b> </summary>

    - **Reboot is pending.** `libc6`, `systemd`, and `dbus` were upgraded under
      running processes. Plan a reboot at a quiet time; after it, run
      `jcradio-start` (Rails does not autostart) and re-check the stream.
    - **DarkIce 1.3 is untested.** The first process restart or reboot will run
      the new binary against the 2020 config. Verify `pcm0c` RUNNING, the
      Icecast source list, and a non-silent stream with a queued song. If it
      fails, `/etc/darkice.cfg` is unchanged and the old package version is
      `1.0.1-999~mp3+1` (source not identified; no `.deb` cached).
    - `certbot.service` shows `failed` from the mid-upgrade run; harmless, but
      `sudo systemctl reset-failed certbot.service` clears it.
    - Future `apt` runs on Stretch need
      `sudo apt-get -o Acquire::Check-Valid-Until=false update`. The legacy
      archive is frozen: this was the last set of Stretch updates, not a path
      to a supported system.
    - Do not `apt upgrade raspotify`; see above.

  </details>
