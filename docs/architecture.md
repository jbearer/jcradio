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

        [TitleExtractorWorker](../app/helpers/stations_helper.rb) is a plain Ruby thread
        inside the application process, despite its worker-style name. It polls the
        shared Spotify player, notices track changes, and updates station ID `1`.
        Its polling delay depends on the estimated remaining track time, with a
        one-second minimum; it sleeps when the player is idle.

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
        subscription for that user replaces the previous one.

      </details>

    ### Audio Delivery

    - <details> <summary> <b>Audio Delivery</b> </summary>

        The [Station model](../app/models/station.rb) has a hard-coded Spotify
        device ID for the Pi and a special case for the shared account's display
        name (`JC Radio`). If the device is missing when the station is idle, the
        add-song path returns a user-facing error instead of a 500.

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

        The home page still has a **Restart Player** button
        (`POST /sessions/librespot_restart` in
        [SessionsController](../app/controllers/sessions_controller.rb)) that
        runs the legacy `librespot-restart` shell function. That function targets
        the 2020 binary with password login, which Spotify no longer accepts. Do
        not use it; restart the systemd service instead. See
        [operations](operations.md).

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
    | Shared Spotify user | `$spotify_user`, restored at startup from `~/jcradio/.nothingtoseehere.yml` | The saved access token is stale after a restart; the first OAuth call refreshes it |
    | Personal Spotify users and library caches | `$client_spotifies`, `$spotify_libraries_cached` | Lost when the process restarts |
    | Next letter and Buddy configuration | Process globals | Not independent per station or shared across processes |
    | Playback poller and LiveRPC subscribers | Ruby thread and in-memory registries | Not a durable job or shared message service |

    Global defaults and station selection are in
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
