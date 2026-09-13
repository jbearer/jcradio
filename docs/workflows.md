# Workflows

This is a code-oriented companion to the [product overview](overview.md).
Routes are defined in [the route file](../config/routes.rb). Joining, adding a
song, and Buddy's turn were exercised live in September 2026; the other paths
are verified in code only.

## Joining and Taking Turns

- <details> <summary> <b>Joining and Taking Turns</b> </summary>

    `POST /sessions` finds an existing user by username and stores the user's ID
    in the session. A joining user is inserted after the current first selector,
    with later positions shifted back. This is different from always joining the
    end of the line. Logging out removes station membership and selection position.
    See [SessionsController](../app/controllers/sessions_controller.rb).

    For an existing member, the lowest `User.position` in the station has the turn.
    After a successful addition, that selector gets the previous maximum position
    plus one. See [User#can_add_to_queue](../app/models/user.rb) and
    [StationsController#update](../app/controllers/stations_controller.rb).

  </details>

## Adding a Song

- <details> <summary> <b>Adding a Song</b> </summary>

    1. Search/browse results open a confirmation dialog. It shows letter and recent
       selection warnings, with an editable next-letter input.
    2. The form posts `source_id`, `song_next_letter`, and `was_recommended` to
       `POST /stations/:id`.
    3. The controller verifies login, membership, and turn order, then resolves the
       Spotify track through [Song.get](../app/models/song.rb).
    4. [Station#queue_song](../app/models/station.rb) requires a shared Spotify
       account and player. If playback is running, it adds the URI to Spotify's
       queue with a direct `RestClient.post`, because the queue endpoint returns a
       non-JSON body that RSpotify's own helper cannot parse. If idle, it attempts
       direct playback on the configured Pi device for the shared account's
       expected display name; a missing device returns an error message rather
       than raising.
    5. A `QueueEntry` records the song, station, selector, queue position, and
       recommendation flag. The controller advances the turn and assigned letter,
       broadcasting a next-turn notification when its participant-count conditions
       are met.

    Spotify calls, database writes, and turn changes are not transactional together.
    The `last_played` timestamp is written by the controller even before it checks
    the error returned by `queue_song`. Treat it as an approximate selection-time
    field, not proof that a track played successfully.

    The letter handoff and overrides are detailed in [letter rules](letter-rules.md).

  </details>

## Finding Songs

- <details> <summary> <b>Finding Songs</b> </summary>

    | Path | Behavior |
    | --- | --- |
    | Spotify text search | Calls `RSpotify::Track.search` with `limit: 10`, the maximum Spotify allows since February 2026; no pagination |
    | Personal Spotify library | Loads saved tracks, caches them for roughly one day, optionally filters by computed first letter; results are not written to the database until a song is chosen |
    | Previously chosen songs | Filters positioned queue entries selected by the current user, using the song's stored first letter |
    | Previously upvoted songs | Filters entries the user upvoted, using stored first letter |
    | Radio history | Searches positioned entries across the shared history using stored first letter |

    History browsing limits the query to 500 recent entries before deduplicating
    songs. An empty letter filter is explicitly supported for the personal-library
    path; it should not be assumed to behave identically in every history path.
    Library browsing used to persist every track before rendering, which locked
    the SQLite database; it now converts without saving.
    See [SongsController](../app/controllers/songs_controller.rb) and the
    [library cache helper](../app/helpers/recommendations_helper.rb).

  </details>

## Recommendations

- <details> <summary> <b>Recommendations</b> </summary>

    [RecommendationsController](../app/controllers/recommendations_controller.rb)
    accepts one to five track/artist seeds. Seeds can come from text search,
    history, upvotes, or a linked Spotify library. Enabled sliders become Spotify
    `target_*` audio-feature options; the request asks for up to 100 tracks and
    then applies an optional first-letter filter locally.

    The supported sliders are in [RecommendationsHelper](../app/helpers/recommendations_helper.rb).
    Genre seeds and min/max feature constraints appear in the historical TODO list,
    not this inspected generation path. Spotify restricted the recommendations
    endpoint for newer developer apps in late 2024; whether the owner's
    replacement app can call it has not been tested.

  </details>

## Buddy

- <details> <summary> <b>Buddy</b> </summary>

    [BuddyController](../app/controllers/buddy_controller.rb) controls membership,
    taste sources, and a solo queue limit. A database user named `Buddy` must exist.
    The default seeds do not create that user.

    [StationsController#buddy_add_song](../app/controllers/stations_controller.rb)
    runs through the station show/refresh path. It checks that Buddy has the turn,
    builds a pool matching the assigned letter from configured history, upvotes,
    or linked libraries, and chooses randomly. If that pool is empty, it falls
    back to matching local song records. The radio-wide Spotify-library source
    is explicitly unimplemented. Queue-size and time-spacing checks limit additions.

    Buddy is not a separate always-running scheduling service. Do not assume it
    continues filling the queue without station requests. Its configuration lives
    in process globals, and some selectable user names are hard-coded.

  </details>

## Listening and Playback Controls

- <details> <summary> <b>Listening and Playback Controls</b> </summary>

    The Spotify polling thread and live browser notifications are described in
    [architecture](architecture.md). The current routed skip action is
    `POST /stations/:id/skip_song`, which invokes Spotify's next-track control.
    An older `next` method and its streaming-engine comment in the controller do
    not describe the active skip route.

    Refreshing wakes the playback poller when possible, checks Buddy's turn, and
    updates timing. Saving the current track uses the listener's linked Spotify
    account. Listening to the shared audio itself depends on the external stream,
    not these metadata/control endpoints.

  </details>

## Social Features and Statistics

- <details> <summary> <b>Social Features and Statistics</b> </summary>

    - [Upvotes](../app/controllers/upvotes_controller.rb) toggle a reaction on a
      particular queue entry, not globally on every occurrence of a song.
    - [Chat](../app/controllers/chat_controller.rb) stores a sender and current
      song reference, expands known custom emoji, and handles username mentions
      and `@here`. Messages are broadcast through LiveRPC.
    - [Plots](../app/views/stations/plots.html.erb) use Plotly for first-letter
      counts, a first-letter/next-letter transition model, projected distributions
      after a chosen number of turns, and character-position frequencies in titles.
      These are analyses of recorded selections and song metadata, not listening
      duration or streaming-audience metrics.

  </details>

Next: [Data model](data-model.md).
