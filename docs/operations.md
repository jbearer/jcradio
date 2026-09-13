# Raspberry Pi Recovery

For the observed installation, start with [Pi overview](pi-overview.md),
[inspection evidence](pi/inspection-2026-09-12.md), and
[Xfinity port forwarding](pi/network-setup.md). The radio remains stopped;
the owner normally starts it manually with `jcradio-start`.

## Known History

- <details> <summary> <b>Known History</b> </summary>

    **Owner context:** a Raspberry Pi served the website behind a DDNS address.
    Moving the Pi and configuring a new router have made hosting difficult.

    **Repository evidence:** the [original README](../README.rdoc) describes SSH to
    `pi@jcradio.ddns.net` on port `10110`, pulling changes inside the checkout,
    and running `jcradio-stop` / `jcradio-start`. The app invokes `librespot-start`.
    The layout retains a commented stream URL on port `8000` ending in `/rapi.mp3`.
    The website was historically accessed on port `3000`.

    **Verified on Pi:** `jcradio-start` is a shell function launching Rails with
    HTTPS on port 3000. Icecast and DarkIce are active; librespot is configured
    to feed them through ALSA loopback. SSH listens on 10110. The website's
    configured certificate expired in November 2021. These observations do not
    prove current public access or end-to-end playback.

    The inspected shell has `jcradio-startstop`, not the README's `jcradio-stop`;
    stop-like functions contain force-kill operations. Do not invoke them as a
    recovery recipe. Some configuration remains protected and unread.

  </details>

## Preserve Before Changing

- <details> <summary> <b>Preserve Before Changing</b> </summary>

    - Identify the actual checkout, branch/commit, Rails environment, service user,
      and database path used by the running installation.
    - Preserve a full Pi image where practical, or a private backup of the database,
      configuration, service definitions, and relevant home-directory scripts.
    - For a live SQLite database, use SQLite's online backup facility or stop writes
      cleanly before copying it. A casual copy during writes may be inconsistent.
    - Preserve secrets separately with restrictive permissions. Database backups
      can include chat, user information, subscriptions, and private VAPID keys.
    - Do not run `db:setup`, `db:reset`, or seeds over the only surviving copy.
    - Avoid pulling changes, rotating credentials, or restarting everything before
      capturing the current working state. Plan those changes after recovery.

    The initial repository-only pass made no Pi connection. The subsequent
    September 12 SSH inspection used read-only queries and a public Icecast
    status GET. It made no backups, configuration changes, service starts, or
    database changes. Preserve the three uncommitted Pi source files as well
    as the database before any future pull or deployment.

  </details>

## Inventory to Recover

- <details> <summary> <b>Inventory to Recover</b> </summary>

    | Area | Questions to Answer |
    | --- | --- |
    | Host | Which Pi model, OS, architecture, Ruby, Bundler, and native packages? |
    | Launch commands | Are the start/stop names scripts, aliases, or shell functions? What do they launch? |
    | Services | Is startup managed by systemd, cron, a login shell, or something else? What starts after reboot? |
    | Spotify device | Which librespot version, account, device name/ID, output backend, and restart policy? |
    | Audio route | How does Spotify output reach the stream? Which capture device, encoder, and stream server? |
    | Stream | Is the service Icecast or something else? Which mount path, bitrate, codec, listener access, and port? |
    | Network | Pi LAN address, router forwarding, DDNS updater, firewall, reverse proxy, and any TLS termination? |
    | OAuth | Who owns the Spotify developer app? Which redirect URIs and permissions are registered? |
    | Data | Is the Pi's database the authoritative history, or are there newer copies elsewhere? |

    Many host, launcher, and audio details now have answers in the
    [inspection record](pi/inspection-2026-09-12.md). The table remains a recovery
    checklist, not a claim that every item is still unknown.

    Inspect script and service contents privately: they may include passwords or
    tokens. Record redacted structure and configuration variable names, not values.
    In particular, preserve the radio OAuth restore file
    `~/jcradio/.nothingtoseehere.yml` privately.

  </details>

## Low-Risk First Checks

- <details> <summary> <b>Low-Risk First Checks</b> </summary>

    Run these manually on the Pi once you have access. They inventory the host;
    they do not restart services or change the router.

    ```sh
    uname -a
    cat /etc/os-release
    ruby -v
    bundle --version
    type -t jcradio-start
    type -t jcradio-stop
    type -t librespot-start
    systemctl list-unit-files --type=service
    ss -ltn
    ```

    Use the same login user/environment as the historical service where possible.
    A command not found in a non-login shell does not prove it was never installed.
    For installed services, inspect status and logs locally, redacting secrets
    before sharing output. If a command requires a password, enter it directly on
    the machine, not into chat.

  </details>

## Diagnose in Layers

- <details> <summary> <b>Diagnose in Layers</b> </summary>

    | Symptom | First Boundary to Check |
    | --- | --- |
    | Website unreachable even on the Pi | Rails process, listening address, local errors, database availability |
    | Works on the Pi but not on the LAN | Bind address and host firewall |
    | Works on LAN but not remotely | Router forwarding, public-address/CGNAT situation, DDNS resolution |
    | Website works but no player is found | Radio OAuth state, Spotify account/device visibility, librespot service |
    | Spotify plays but listening tab is silent | Audio output/capture, encoder, stream server, mount URL |
    | Audio plays but title/queue looks stale | Polling thread, Spotify state calls, queue cursor, SSE connection |
    | Buddy does not add songs | Buddy user/membership, turn, matching songs, limits, station refresh path |

    Change one layer at a time and record the exact failure. Do not treat an
    unreachable website as proof that the application or Spotify is broken.

    Owner context is that the new Xfinity network lacks configured forwarding.
    Forwarding affects internet access, not the local server bind. Xfinity's
    documented DHCP device requirement may also conflict with the Pi's static
    Ethernet address. Follow the [network setup guide](pi/network-setup.md)
    before any separately approved address or router changes.

  </details>

## Before Public Hosting

- <details> <summary> <b>Before Public Hosting</b> </summary>

    The inspected app uses username-only login, skips CSRF verification in
    development, and exposes host/playback actions without an established admin
    boundary. The runtime is old. A public cloud IP does not resolve these risks.

    Before restoring public access, plan authentication/authorization, supported
    dependencies, secret handling, HTTPS, backups, and restricted operational
    controls. Review [the OAuth initializer](../config/initializers/omniauth.rb),
    [Rails secrets configuration](../config/secrets.yml), and private host files
    without copying their secret values into these docs.

  </details>

Next: [Future hosting](hosting.md).
