# Operating the Pi

How to start, check, back up, and troubleshoot the running installation.
Facts here were checked on the Pi on **2026-09-13**. For how the pieces fit
together, see [Pi overview](pi-overview.md). Historical inspection and repair
records are under [Pi records](pi/README.md).

## Components and How They Start

- <details open> <summary> <b>Components and How They Start</b> </summary>

    | Component | Runs as | Started by | Survives reboot? |
    | --- | --- | --- | --- |
    | Rails website (HTTPS :3000) | `pi` | `jcradio-web.service` (systemd, since 2026-09-13) | Yes, enabled; restarts on failure |
    | Spotify player (librespot 0.8.0) | `pi` | `jcradio-player.service` (systemd) | Yes, enabled; restarts on failure |
    | DarkIce MP3 encoder (Debian `1.3-0.1` since 2026-09-13; verified after reboot) | root | `/etc/rc.local` via `/home/pi/darkice.sh` | Yes |
    | Icecast (`:8000/rapi.mp3`) | `icecast2` | `icecast2` init service | Yes |
    | No-IP DDNS updater | `nobody` | `noip2.service` | Yes |
    | SSH (:10110) | root | `ssh.service` | Yes |
    | TLS renewal (certbot) | root | `certbot.timer`, twice daily | Yes |

    Rails needs `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` and refuses to
    boot without them. The unit reads them from `/home/pi/.config/jcradio/env`
    (mode 600, a copy of the two `export` lines in `.bashrc`); interactive
    shells still get them from `.bashrc`. If the client secret is rotated,
    update both files. The shared radio account is restored from
    `~/jcradio/.nothingtoseehere.yml` when Rails boots (logged as
    `Radio Spotify account restored`), and the playback poller thread starts
    with it (`PlaybackPoller started`).

    The legacy 2020 `/usr/bin/librespot` is no longer launched anywhere: its
    `/etc/rc.local` line and the `librespot-*` `.bashrc` functions were removed
    on 2026-09-13, along with the site's Restart Librespot button.

  </details>

## Routine Commands

- <details open> <summary> <b>Routine Commands</b> </summary>

    Run these on the Pi (`ssh jcradio-pi`), from an interactive shell so RVM
    and the environment variables load.

    ### Health Check and Logs

    - <details open> <summary> <b>Health Check and Logs</b> </summary>

        ```sh
        jcradio-status                  # website, player, encoder, stream, certificate on one screen
        jcradio-logs                    # last 50 lines of the Rails log
        jcradio-logs rails 200          # more lines
        jcradio-logs web                # systemd journal for the Rails unit (boot errors land here)
        jcradio-logs player             # librespot log (~/.local/state/jcradio-player/player.log)
        jcradio-logs icecast            # /var/log/icecast2/error.log
        jcradio-logs rails -f           # follow
        ```

        After a reboot everything comes back on its own, the website included
        since 2026-09-13; Rails takes about 30 seconds to start listening on
        the Pi 3 and the first page a couple of seconds more, so give
        `jcradio-status` a moment before reading it as a failure.

      </details>

    ### Website

    - <details open> <summary> <b>Website</b> </summary>

        ```sh
        jcradio-start                                   # sudo systemctl start jcradio-web
        jcradio-stop                                    # sudo systemctl stop jcradio-web
        jcradio-restart                                 # sudo systemctl restart jcradio-web; needed after config/ changes
        systemctl status jcradio-web                    # state, PID, last log lines
        ss -ltn | grep ':3000'                          # is it listening?
        ```

        The unit is [jcradio-web.service](../script/pi-recovery/jcradio-web.service):
        `bundle exec rails server` through the RVM wrapper, bound to
        `ssl://0.0.0.0:3000` with the Let's Encrypt key and chain, in the
        foreground so systemd owns the process; `tmp/pids/server.pid` is still
        written. It replaced the daemonized `rails server -d` that the original
        `jcradio-start` function ran (backup: `~/jcradio-recovery/2026-09-12/bashrc-before-jcradio-web`).

        Rails runs in the development environment: edits under `app/` reload per
        request; anything under `config/` needs `jcradio-restart`. Since
        2026-09-13 the environment eager-loads `app/` at boot (adds 3-5 s, avoids
        an autoload race between the first concurrent requests) and serves
        concatenated assets; see [development](development.md).
        `jcradio-startstop` in `.bashrc` is `pkill -9 ruby`; avoid it (systemd
        would just restart the site anyway). `.bashrc` sources the functions from
        [jcradio-shell-functions.bash](../script/pi-recovery/jcradio-shell-functions.bash),
        so editing that file in the checkout changes the commands.

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

    ### Listening Page and Icons

    - <details> <summary> <b>Listening Page and Icons</b> </summary>

        The listener entry point is
        [http://jcradio.ddns.net:8000/listen.html](http://jcradio.ddns.net:8000/listen.html).
        Icecast serves it from `/usr/share/icecast2/web/`, separately from the
        Rails website on HTTPS port 3000. Pulling changes into `~/jcradio` or
        restarting Rails does **not** update Icecast's files.

        The sources are [listen.html](../public/listen.html),
        [favicon.ico](../public/favicon.ico),
        [favicon-32x32.png](../public/favicon-32x32.png), and
        [apple-touch-icon.png](../public/apple-touch-icon.png). Keep edits in
        these repository files, sync them to the Pi checkout, then deploy all
        four files. The page's root-relative icon URLs resolve on port 8000;
        files in Rails' `public/` or asset pipeline alone do not satisfy them.

        Run on the Pi after syncing the sources. Back up the deployed files,
        install the icons before the page, and preserve web-readable permissions:

        ```bash
        cd ~/jcradio &&
        backup=$(mktemp -d /home/pi/jcradio-recovery/listener-web-XXXXXX) &&
        cp -p /usr/share/icecast2/web/{listen.html,favicon.ico,favicon-32x32.png,apple-touch-icon.png} "$backup/" &&
        sudo -n install -o root -g root -m 0644 public/favicon.ico public/favicon-32x32.png public/apple-touch-icon.png /usr/share/icecast2/web/ &&
        sudo -n install -o root -g root -m 0644 public/listen.html /usr/share/icecast2/web/listen.html
        ```

        No Icecast or Rails restart is needed. From the laptop, verify the
        **HTTP port-8000** page and assets, not the HTTPS port-3000 copies:

        ```bash
        curl -fsS --max-time 15 http://jcradio.ddns.net:8000/listen.html | head -12
        for asset in listen.html favicon.ico favicon-32x32.png apple-touch-icon.png; do
          curl -fsS --max-time 15 -o /dev/null -w "$asset: HTTP %{http_code}, %{content_type}\n" "http://jcradio.ddns.net:8000/$asset" || break
        done
        ```

        Expect favicon links in the page head, HTTP 200 for every file, and
        image MIME types for the icons. On 2026-09-13, the Icecast page lacked
        those links and all three icon URLs returned 404 despite working on
        Rails. Deploying the four files fixed the mismatch; public response
        hashes matched the repository files. The previous page is backed up at
        `~/jcradio-recovery/listener-favicon-2026-09-13-qavCUc/` on the Pi.
        Only investigate Chrome's favicon cache after these checks pass.

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
    `~/jcradio-recovery/2026-09-13-perf` holds the online backup and `schema.rb`
    taken just before the `songs.source_id` index migration ran on the live
    database.

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
    | Website unreachable on the Pi | `systemctl status jcradio-web` and `jcradio-logs web`; a missing `~/.config/jcradio/env` or certificate path stops the boot; then `log/development.log` |
    | Works on the Pi but not on the LAN | Bind is `0.0.0.0:3000`, so look at the host firewall |
    | Browser shows a certificate warning | `openssl x509 -dates` on `:3000` vs `sudo certbot certificates`; if certbot is newer, `jcradio-restart`; if both are old, see the certificate section above |
    | Works on LAN but not remotely | Router forwarding for 3000/8000, DDNS resolution; see [network setup](pi/network-setup.md) |
    | Listening page or tab icon is stale/missing | Check the HTTP port-8000 page and icon URLs; deploy the repository copies to Icecast's webroot, not just Rails; see [Listening Page and Icons](#listening-page-and-icons) |
    | `401 Unauthorized` from `RSpotify` after a restart | The token refresh patch in `config/initializers/rspotify_token_refresh.rb` is missing or Rails was not restarted after pulling it |
    | "Radio Spotify device is unavailable" when adding a song | The watchdog already tried one restart (`PlayerWatchdog:` lines in `log/development.log`); `systemctl status jcradio-player`; auth marker in `player.log`; device name must be `JCRadio` |
    | Spotify plays but the stream is silent | Loopback status, DarkIce process, Icecast source list |
    | Song accepted but page shows an error, or Buddy never takes a turn | `log/development.log` for the exception class; historically a JSON parse of the queue response |
    | Title/queue looks stale | Polling thread and SSE; a Rails restart resets both |
    | `Circular dependency detected while autoloading constant ...` right after a restart | Two requests autoloaded the same class at once; `config.eager_load = true` in `development.rb` prevents it, so check that it is still set. The losing request got a 500; if it was `/sessions/subscribe`, that tab has no live updates until reloaded |
    | Spotify calls slow again (about 300 ms each) or `ServerBrokeConnection` in the log | `config/initializers/rest_client_keep_alive.rb` missing or Rails not restarted after pulling it; `bin/rails runner script/perf/bench-keepalive.rb` shows whether calls 2-5 reuse the connection |
    | A page feels slow | `ruby script/perf/log-timings.rb log/development.log <date>` for per-action p50/p90, then [development](development.md#tests-and-checks) for the other perf scripts |

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
