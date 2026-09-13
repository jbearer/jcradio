# Operating the Pi

How to start, check, back up, and troubleshoot the running installation.
Facts here were checked on the Pi on **2026-09-13**. For how the pieces fit
together, see [Pi overview](pi-overview.md). Historical inspection and repair
records are under [Pi records](pi/README.md).

## Components and How They Start

- <details open> <summary> <b>Components and How They Start</b> </summary>

    | Component | Runs as | Started by | Survives reboot? |
    | --- | --- | --- | --- |
    | Rails website (HTTPS :3000) | `pi` | `jcradio-start` shell function in `/home/pi/.bashrc` | **No**, start it manually after a reboot |
    | Spotify player (librespot 0.8.0) | `pi` | `jcradio-player.service` (systemd) | Yes, enabled; restarts on failure |
    | DarkIce MP3 encoder (Debian `1.3-0.1` since 2026-09-13; old build still the running process) | root | `/etc/rc.local` via `/home/pi/darkice.sh` | Yes |
    | Icecast (`:8000/rapi.mp3`) | `icecast2` | `icecast2` init service | Yes |
    | No-IP DDNS updater | `nobody` | `noip2.service` | Yes |
    | SSH (:10110) | root | `ssh.service` | Yes |
    | TLS renewal (certbot) | root | `certbot.timer`, twice daily | Yes |

    `jcradio-start` needs `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` in
    the environment; `.bashrc` exports them. Rails refuses to boot without
    them. The shared radio account is restored from
    `~/jcradio/.nothingtoseehere.yml` on the first visit to the home page.

    The legacy 2020 `/usr/bin/librespot` is no longer launched anywhere: its
    `/etc/rc.local` line and the `librespot-*` `.bashrc` functions were removed
    on 2026-09-13, along with the site's Restart Librespot button.

  </details>

## Routine Commands

- <details open> <summary> <b>Routine Commands</b> </summary>

    Run these on the Pi (`ssh jcradio-pi`), from an interactive shell so RVM
    and the environment variables load.

    ### Website

    - <details open> <summary> <b>Website</b> </summary>

        ```sh
        jcradio-start                                   # daemonized rails server, HTTPS 0.0.0.0:3000
        jcradio-stop                                    # SIGTERM via PID file, SIGKILL after 15s
        jcradio-restart                                 # stop + start; needed after config/ changes
        ss -ltn | grep ':3000'                          # is it listening?
        tail -n 50 ~/jcradio/log/development.log        # recent requests and errors
        ```

        Rails runs in the development environment: edits under `app/` reload per
        request; anything under `config/` needs `jcradio-restart`.
        `jcradio-startstop` in `.bashrc` is `pkill -9 ruby`; avoid it.
        The functions are kept in
        [jcradio-shell-functions.bash](../script/pi-recovery/jcradio-shell-functions.bash).

      </details>

    ### Player

    - <details open> <summary> <b>Player</b> </summary>

        ```sh
        systemctl status jcradio-player
        jcradio-player-restart                              # sudo systemctl restart jcradio-player + status
        tail -n 30 ~/.local/state/jcradio-player/player.log
        ruby ~/jcradio/script/pi-recovery/check-player.rb   # PID, version, auth marker, error marker
        ```

        The unit runs [run-player.sh](../script/pi-recovery/run-player.sh),
        which starts the private binary through
        [librespot-current](../script/pi-recovery/librespot-current) with device
        name `JCRadio`, ALSA output `plughw:Loopback,1`, 320 kbps, and a
        credential cache in `~/.local/state/jcradio-player`. The log's `ERROR`
        lines seen so far are `spirc ... 400 Bad Request` around track changes
        and one `Connection to server closed`; playback continued through both.

        If the player stops authenticating (`Authentication failed` in the log),
        the cached credentials need renewing. Stop the service, run the OAuth
        flow once through an SSH tunnel, log in as JC Radio in the browser, then
        start the service again:

        ```sh
        sudo systemctl stop jcradio-player
        # from the laptop:
        ssh -L 127.0.0.1:5588:127.0.0.1:5588 jcradio-pi '~/jcradio/script/pi-recovery/run-player.sh --enable-oauth --oauth-port 5588'
        ssh jcradio-pi 'ruby ~/jcradio/script/pi-recovery/oauth-link.rb'   # prints the authorize URL
        # open the URL, log in as JC Radio, then Ctrl-C the tunnel command
        sudo systemctl start jcradio-player
        ```

      </details>

    ### Stream

    - <details> <summary> <b>Stream</b> </summary>

        ```sh
        curl -s http://127.0.0.1:8000/status-json.xsl | python3 -m json.tool | grep -E 'listeners|listenurl'
        head -1 /proc/asound/Loopback/pcm1p/sub0/status     # RUNNING while a track plays, closed when idle
        ```

        From the laptop, measure six seconds of the stream. Around -20 dB mean
        is music; -91 dB is silence (player idle or nothing queued):

        ```sh
        ffmpeg -hide_banner -nostdin -i http://jcradio.ddns.net:8000/rapi.mp3 -t 6 -af volumedetect -f null - 2>&1 | grep _volume
        ```

        DarkIce and Icecast have not needed attention. Their configuration is
        `/etc/darkice.cfg` (readable) and `/etc/icecast2/icecast.xml`
        (root/icecast only).

      </details>

    ### Certificate

    - <details> <summary> <b>Certificate</b> </summary>

        The Let's Encrypt certificate for `jcradio.ddns.net` was renewed on
        2026-09-13 (`sudo certbot renew`, after the owner forwarded TCP 80 on
        the Xfinity gateway) and is valid until 2026-12-12. Renewal is
        automatic from here:

        - `certbot.timer` runs `certbot -q renew` twice a day; certbot renews
          when fewer than 30 days remain, so expect a renewal around
          2026-11-12 and every ~60 days after.
        - The renewal uses the `standalone` authenticator: certbot briefly
          listens on port 80 itself, so **TCP 80 must stay forwarded to the
          Pi** and nothing else may bind it. No web server on 80 is needed.
        - Puma reads the key and chain once at startup, so
          `/etc/letsencrypt/renewal-hooks/deploy/jcradio-restart-rails.sh`
          (root, 0755; source in
          [certbot-deploy-jcradio.sh](../script/pi-recovery/certbot-deploy-jcradio.sh))
          runs `jcradio-restart` as `pi` after each successful renewal. It
          logs to `/var/log/jcradio-cert-deploy.log`. Expect one Rails
          restart, at a random time of day, per renewal; open SSE streams
          mean the stop usually ends in SIGKILL after 15 s, which is normal.

        ```sh
        sudo certbot certificates                        # lineage, expiry, paths
        systemctl list-timers certbot.timer              # next scheduled attempt
        sudo cat /var/log/jcradio-cert-deploy.log        # hook runs
        echo | openssl s_client -connect 127.0.0.1:3000 -servername jcradio.ddns.net 2>/dev/null | openssl x509 -noout -dates   # what Puma is serving
        sudo certbot renew --dry-run                     # staging test of the challenge; does NOT run deploy hooks in certbot 0.28
        ```

        To test the hook itself (restarts Rails once):

        ```sh
        sudo env RENEWED_LINEAGE=/etc/letsencrypt/live/jcradio.ddns.net RENEWED_DOMAINS=jcradio.ddns.net /etc/letsencrypt/renewal-hooks/deploy/jcradio-restart-rails.sh
        ```

        If a renewal succeeds but the site still serves the old certificate,
        run `jcradio-restart` and read the hook log. If renewal itself fails
        (`/var/log/letsencrypt/letsencrypt.log`), check that port 80 is still
        forwarded to the Pi's current address and that DDNS resolves.

      </details>

  </details>

## Backups

- <details> <summary> <b>Backups</b> </summary>

    `~/jcradio-recovery/2026-09-12` on the Pi (mode 700) holds the pre-repair
    state: an online SQLite backup of the database, the OAuth restore file, the
    original `/usr/bin/librespot`, `.bashrc`, `/etc/rc.local`,
    `/etc/default/raspotify`, and the three Rails source files changed that day.
    `~/jcradio-recovery/incoming-2026-09-12` holds the staged player archive.

    Take a fresh database backup before any schema or data operation. Use
    SQLite's online backup, not `cp`, because Rails is writing:

    ```sh
    sqlite3 ~/jcradio/db/development.sqlite3 ".backup '$HOME/jcradio-recovery/development-$(date +%F).sqlite3'"
    ```

    Backups contain chat, users, push subscriptions, and VAPID private keys.
    Keep them on the Pi or in private storage, never in the repository.

  </details>

## Diagnose in Layers

- <details> <summary> <b>Diagnose in Layers</b> </summary>

    | Symptom | First Thing to Check |
    | --- | --- |
    | Website unreachable on the Pi | `ss -ltn` for :3000; `jcradio-start` was run in a shell with the Spotify variables; `log/development.log` |
    | Works on the Pi but not on the LAN | Bind is `0.0.0.0:3000`, so look at the host firewall |
    | Browser shows a certificate warning | `openssl x509 -dates` on `:3000` vs `sudo certbot certificates`; if certbot is newer, `jcradio-restart`; if both are old, see the certificate section above |
    | Works on LAN but not remotely | Router forwarding for 3000/8000, DDNS resolution; see [network setup](pi/network-setup.md) |
    | `401 Unauthorized` from `RSpotify` after a restart | The token refresh patch in `config/initializers/rspotify_token_refresh.rb` is missing or Rails was not restarted after pulling it |
    | "Radio Spotify device is unavailable" when adding a song | `systemctl status jcradio-player`; auth marker in `player.log`; device name must be `JCRadio` |
    | Spotify plays but the stream is silent | Loopback status, DarkIce process, Icecast source list |
    | Song accepted but page shows an error, or Buddy never takes a turn | `log/development.log` for the exception class; historically a JSON parse of the queue response |
    | Title/queue looks stale | Polling thread and SSE; a Rails restart resets both |

    Change one layer at a time. An unreachable website is not evidence that
    Spotify or the player is broken.

  </details>

## Before Public Hosting

- <details> <summary> <b>Before Public Hosting</b> </summary>

    The app uses username-only login, skips CSRF verification in development,
    and exposes host/playback actions without an admin boundary. The runtime is
    old. A public cloud IP does not resolve these risks.

    Before widening access, plan authentication/authorization, supported
    dependencies, secret handling, backups, and restricted operational
    controls. Review [the OAuth initializer](../config/initializers/omniauth.rb)
    and [Rails secrets configuration](../config/secrets.yml) without copying
    secret values into these docs.

  </details>

## Historical

- <details> <summary> <b>Historical</b> </summary>

    The [original README](../README.rdoc) describes SSH to `pi@jcradio.ddns.net`
    on port 10110 and `jcradio-stop` / `jcradio-start`; `jcradio-stop` does not
    exist on the Pi, `jcradio-startstop` does. Between roughly 2024 and
    September 2026 the radio was down: the 2020 librespot could no longer log in
    (Spotify dropped password authentication), Spotify capped search results at
    10, and its queue endpoint stopped returning JSON. The
    [repair journal](pi/repair-2026-09-12.md) records how each was fixed.

  </details>

Next: [Future hosting](hosting.md).
