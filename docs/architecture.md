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
        Stream -.->|Separate listening tab: owner context|Listeners[Listeners]
    ```

    Solid connections describe inspected code and recovered host configuration,
    not proof of current end-to-end operation. The exact historical listening-tab
    workflow still needs owner confirmation. See [Pi overview](pi-overview.md).

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

        The app calls a host-local `librespot-start` command from
        [SessionsController](../app/controllers/sessions_controller.rb). The
        [Station model](../app/models/station.rb) has a hard-coded Spotify device ID
        for the Pi and a special case for the shared account's display name.

        The [layout](../app/views/layouts/application.html.erb) contains a **commented-out**
        audio element pointing to the historical
        `http://jcradio.ddns.net:8000/rapi.mp3` address.

        **Verified on Pi, September 12, 2026:** librespot is configured to output
        to `plughw:Loopback,1`; DarkIce captures `plughw:Loopback,0` and encodes
        320 kbps MP3 for Icecast at `localhost:8000/rapi.mp3`. Icecast reported
        the source active, while librespot was absent and the playback endpoint
        closed. Audio content was not tested. Full Icecast configuration was
        permission-protected. See [inspection evidence](pi/inspection-2026-09-12.md).

        The Pi also has uncommitted edits changing the home-page player action
        to `librespot-restart`; the local source still calls `librespot-start`.

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
    | Shared Spotify user | `$spotify_user`, with a YAML restore file under the host user's home directory | Depends on local credentials and startup behavior |
    | Personal Spotify users and library caches | `$client_spotifies`, `$spotify_libraries_cached` | Lost when the process restarts |
    | Next letter and Buddy configuration | Process globals | Not independent per station or shared across processes |
    | Playback poller and LiveRPC subscribers | Ruby thread and in-memory registries | Not a durable job or shared message service |

    Global defaults and station selection are in
    [ApplicationController](../app/controllers/application_controller.rb).
    The restore file is `~/jcradio/.nothingtoseehere.yml`; treat it as a credential
    file, not ordinary project documentation.

  </details>

## Deployment Implications

- <details> <summary> <b>Deployment Implications</b> </summary>

    The current design assumes a shared application process in several important
    paths. Adding workers or replicas would not automatically share Spotify login,
    the assigned letter, Buddy settings, or live connections. Moving only Rails
    also does not move the audio chain.

    These are constraints to measure and resolve during recovery, not decisions to
    rewrite the application or select a hosting provider now.

  </details>

Next: [Letter rules](letter-rules.md).
