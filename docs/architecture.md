# Architecture

## The Main Pieces

- <details> <summary> <b>The Main Pieces</b> </summary>

    **Verified in code:** JC Radio is a Rails 4.2.8 application, with server-rendered
    ERB views, JavaScript/jQuery interactions, SQLite persistence, and Spotify API
    integration through RSpotify. It is not a separate frontend/backend project.
    See the [Gemfile](../Gemfile), [layout](../app/views/layouts/application.html.erb),
    and [database schema](../db/schema.rb).

    ```mermaid
    flowchart TD
        Browser[Participants' browsers] -->|Pages and form or AJAX requests|Rails[Rails application]
        Rails -->|Server-Sent Events|Browser
        Rails <-->|Persistent records|DB[(SQLite)]
        Rails -->|Search, queue, playback state, libraries|Spotify[Spotify APIs]
        Spotify -->|Playback control|Device[Spotify Connect device]
        Device -->|Configured ALSA loopback|Encoder[DarkIce MP3 encoder]
        Encoder -->|320 kbps MP3|Stream[Icecast on Pi port 8000]
        Stream -.->|Separate listening tab|Listeners[Listeners]
    ```

    Solid connections describe inspected code and the Pi configuration verified
    working in September 2026. Listeners open the Icecast URL directly in a
    separate tab. See [Pi overview](pi-overview.md).

  </details>

## Three Separate Flows

- <details> <summary> <b>Three Separate Flows</b> </summary>

    ### Selection and Queue State

    - <details> <summary> <b>Selection and Queue State</b> </summary>

        The browser submits a Spotify track ID to `POST /stations/:id`.
        [StationsController#update](../app/controllers/stations_controller.rb) checks
        login, membership, and turn order. [Station#queue_song](../app/models/station.rb)
        sends the track to Spotify and creates a `QueueEntry`. The controller then
        advances the selector and sets the next letter.

        There are therefore two queues to reconcile: Spotify's actual playback queue
        and Rails' records of who selected what. They are not one atomic operation.

      </details>

    ### Playback State and Browser Updates

    - <details> <summary> <b>Playback State and Browser Updates</b> </summary>

        [PlaybackPoller](../lib/playback_poller.rb) is one Ruby thread inside the
        application process, started at boot by
        [config/initializers/jcradio.rb](../config/initializers/jcradio.rb) when the
        process is the web server. It polls the radio account's player, notices
        track changes, updates the default station, lets Buddy take his turn, and
        nudges a listener whose turn it is when the queue is about to run dry. Its
        polling delay is a tenth of the estimated remaining track time, with a
        one-second minimum; it sleeps when the player is idle until a page load or
        radio sign-in wakes it.

        [Station#next_song](../app/models/station.rb) searches forward in the local
        queue for the track Spotify reports, updates the cursor when a match exists,
        and records an unpositioned entry when there is no match. It then notifies
        clients of the current song and timing. This is an attempt to recover from
        queue drift, not a guarantee of sample-accurate synchronization.

        The browser opens `/sessions/subscribe` using `EventSource`.
        [LiveRPC](../lib/live-rpc.rb) sends function names and arguments as
        Server-Sent Events; [the browser handler](../app/assets/javascripts/live-rpc.js.erb)
        dispatches them. This is not WebSockets or Rails Action Cable. Connections and
        pending messages are held in memory, keyed by user ID; opening another live
        subscription for that user replaces the previous one. The client installs no
        error handler, so a subscribe request that fails with a non-200 status leaves
        that tab without live updates until it is reloaded.

        Opening the queue page (`GET /stations/1`) renders from the database and
        then runs [Station#refresh_playback](../app/models/station.rb) (wake the
        poller, Buddy's turn check, timing push to clients) through
        `PlaybackPoller.refresh_later`, a short-lived background thread, one at a
        time, so the page is not held for the Spotify round trip. The refresh
        button (`POST /stations/1/refresh`) still runs it synchronously.

      </details>

    ### Audio Delivery

    - <details> <summary> <b>Audio Delivery</b> </summary>

        The [Station model](../app/models/station.rb) plays through the Pi's Spotify
        Connect device (`SpotifyAccounts.radio_device_id`, overridable with the
        `JCRADIO_SPOTIFY_DEVICE_ID` environment variable) and has a special case for
        the shared account's display name (`JC Radio`). If the device is missing
        when the station is idle, the add-song path asks
        [PlayerWatchdog](../lib/player_watchdog.rb) to restart `jcradio-player`
        (`sudo -n systemctl restart jcradio-player`, overridable with
        `JCRADIO_PLAYER_RESTART`), waits up to 20 s for Spotify to list the device
        again, and retries once; otherwise it returns a user-facing error instead
        of a 500. The poller also has the watchdog check `me/player/devices` once
        a minute while idle, because librespot can keep its TCP session after a
        Spotify disconnect while its Connect registration is gone (seen
        2026-09-14). Restarts are at most one per five minutes.

        The [layout](../app/views/layouts/application.html.erb) contains a **commented-out**
        audio element pointing to `http://jcradio.ddns.net:8000/rapi.mp3`; the
        sidebar volume button is wired to that element and is inert while it is
        commented out. Listeners open the stream URL in their own tab.

        **Verified on Pi, September 2026:** librespot 0.8.0 (run as the
        `jcradio-player` systemd service, device name `JCRadio`) outputs to
        `plughw:Loopback,1`; DarkIce captures `plughw:Loopback,0` and encodes
        320 kbps MP3 for Icecast at `localhost:8000/rapi.mp3`. Non-silent audio
        was decoded from the stream while a track played. Full Icecast
        configuration is permission-protected and was not read.

        The home page's former **Restart Librespot** button
        (`POST /sessions/librespot_restart`) was removed on 2026-09-13; it ran the
        legacy password-login launcher. Restart the player with
        `jcradio-player-restart` (wraps `sudo systemctl restart jcradio-player`).
        See [operations](operations.md).

        Short Spotify previews in search results are separate from the shared stream.

      </details>

  </details>

## Accounts and State

- <details> <summary> <b>Accounts and State</b> </summary>

    An application username and a Spotify account are different identities.
    Application login selects an existing user without a password check.
    The first Spotify OAuth callback, when no radio account is loaded, becomes
    the shared radio account. Later callbacks link personal accounts to logged-in
    users. See [sessions](../app/controllers/sessions_controller.rb) and
    [Spotify callback handling](../app/controllers/stations_controller.rb).

    | State | Where It Lives | Consequence |
    | --- | --- | --- |
    | Songs, entries, users, station cursor, chat, reactions | SQLite | Database contents matter beyond the schema |
    | Next letter and Buddy settings | `stations.next_letter`, `stations.buddy_taste`, `stations.buddy_max_songs` (since 2026-09-14) | Survive restarts; the letter falls back to the last queued song's `next_letter` when unset |
    | Shared Spotify user | [SpotifyAccounts](../lib/spotify_accounts.rb)`.radio`, restored at boot from `~/jcradio/.nothingtoseehere.yml` | The saved access token is stale after a restart; the first OAuth call refreshes it |
    | Personal Spotify users and library caches | `SpotifyAccounts.linked`/`.library`, in memory keyed by username | Lost when the process restarts |
    | Playback poller and LiveRPC subscribers | [PlaybackPoller](../lib/playback_poller.rb) thread and in-memory registries | Not a durable job or shared message service |
    | Open HTTPS connections to Spotify | In-memory pool in [config/initializers/rest_client_keep_alive.rb](../config/initializers/rest_client_keep_alive.rb) | Reconnects transparently; nothing to persist |

    `SpotifyAccounts`, `PlaybackPoller`, and `LiveRPC` live in `lib/` and are
    required once by [config/initializers/jcradio.rb](../config/initializers/jcradio.rb)
    so their in-memory state survives development-mode code reloads; everything
    under `app/` is reloaded. The default station is `Station.default` (ID 1),
    set for every request in
    [ApplicationController](../app/controllers/application_controller.rb).
    The restore file is a credential file, not ordinary project documentation.

    Spotify's 401 body changed wording in 2026, which broke RSpotify 2.9.2's
    built-in token refresh.
    [config/initializers/rspotify_token_refresh.rb](../config/initializers/rspotify_token_refresh.rb)
    patches `RSpotify::User.oauth_send` to refresh on any 401. The developer
    app's client ID and secret come from the `SPOTIFY_CLIENT_ID` and
    `SPOTIFY_CLIENT_SECRET` environment variables read by
    [config/initializers/omniauth.rb](../config/initializers/omniauth.rb); Rails
    refuses to boot without them.

    RSpotify's transport, RestClient 2.0.2, opens a new TLS connection per call.
    [config/initializers/rest_client_keep_alive.rb](../config/initializers/rest_client_keep_alive.rb)
    hands RestClient pooled `Net::HTTP` connections per host that stay open
    between calls (60 s idle limit; `Net::HTTP` reconnects on a closed socket).
    `Station#internal_spotify_add_to_queue` retries its POST once if a pooled
    connection turns out to be dead, because `Net::HTTP` only retries idempotent
    verbs itself.

  </details>

## Performance Characteristics

- <details> <summary> <b>Performance Characteristics</b> </summary>

    Measured on the Pi 3 on 2026-09-13 with the scripts in
    [script/perf](../script/perf) (log aggregation, HTTP page timing, in-process
    micro-benchmarks, a SQLite index trial on a database copy, and a Spotify
    idle-connection probe). The Pi's CPU is the limit, not the network: the
    public DDNS path adds about 25 ms over the LAN.

    | Component | Cost | Notes |
    | --- | --- | --- |
    | Rails boot | 24-26 s to listening; 29 s with eager loading | 33-36 s of CPU loading gems; Ruby 2.4 and Rails 4.2 offer no faster path |
    | First request after boot | About 2 s | Template compilation and asset digests |
    | One Spotify API call | About 280 ms cold, 60-80 ms on a kept-alive connection | DNS+TCP+TLS was about 205 ms of each cold call |
    | Queue page `GET /stations/1` | About 200 ms server time, anonymous LAN 240-300 ms | Was 870 ms while it waited for Spotify and Buddy |
    | Home and browse pages | 120-180 ms server time | Were 500-560 ms |
    | 120-row results table, logged in | About 320 ms, 5 queries | Was 2.3 s and 722 queries |
    | History browse query | About 200 ms | Was 1.75 s (one song query per entry) |
    | Asset requests per page | 2 bundles, browser-cached for a year | Were 33 files in debug mode, about 55 ms each |
    | TLS handshake to the Pi | 110-130 ms | Once per browser connection |

    What made the difference: `current_user` is memoized per request
    ([ApplicationHelper](../app/helpers/application_helper.rb)); the results
    partial computes the add-button permission once; history browsing queries
    `Song` directly with `GROUP BY`; `Station#queue_before` eager-loads songs and
    selectors; `config.assets.debug` is off; `songs.source_id` is indexed;
    the queue page defers its Spotify refresh; Spotify connections are pooled.

    Two SQLite indexes were tried and rejected on a copy of the database:
    `queue_entries.station_id` and `songs.first_letter` both made the queue and
    browse queries about twice as slow, because SQLite preferred them over the
    rowid/position order. Every row has the same station.

    Remaining known costs: `Song#to_json` per results row (about 190 ms per 120
    rows), the 3.5 MB Plotly script loaded in the layout `<head>` on every page,
    Buddy's own selection pool still loading one song per entry when it is
    Buddy's turn, and the Fuzzily `trigrams` table (about 197,000 rows) written
    on every `Song.create` although the UI no longer uses fuzzy search.
    `vcgencmd get_throttled` reported under-voltage and past throttling; a
    stronger power supply may help the CPU-bound parts.

  </details>

## Deployment Implications

- <details> <summary> <b>Deployment Implications</b> </summary>

    The current design assumes a shared application process in several important
    paths. Adding workers or replicas would not automatically share Spotify login,
    the assigned letter, Buddy settings, or live connections. Moving only Rails
    also does not move the audio chain.

    These are constraints to measure and resolve before any move, not decisions to
    rewrite the application or select a hosting provider now.

  </details>

Next: [Letter rules](letter-rules.md).
