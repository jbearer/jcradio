# Development and Code Map

## Toolchain

- <details> <summary> <b>Toolchain</b> </summary>

    | Component | Evidence |
    | --- | --- |
    | Ruby 2.4.9 (RVM) | [Original setup notes](../README.rdoc); confirmed on the Pi |
    | Rails 4.2.8 | [Gemfile](../Gemfile) |
    | Bundler 1.17.3 | [Lockfile](../Gemfile.lock) |
    | RSpotify 2.9.2, omniauth-oauth2 1.3.1 | [Lockfile](../Gemfile.lock) |
    | SQLite, Puma, Sass, CoffeeScript, jQuery, Turbolinks | [Gemfile](../Gemfile) |
    | librespot 0.8.0 (private install) | [Pi overview](pi-overview.md) |

    These are legacy versions, not a recommended new public-server stack. The
    original README warns against an omniauth-oauth2 update that broke the old
    RSpotify integration; keep the lockfile pinned. Three places depend on gem
    internals and must be re-checked if RSpotify or RestClient is ever bumped:
    [config/initializers/rspotify_token_refresh.rb](../config/initializers/rspotify_token_refresh.rb)
    (RSpotify 2.9.2 `oauth_send`),
    [config/initializers/rest_client_keep_alive.rb](../config/initializers/rest_client_keep_alive.rb)
    (RestClient 2.0.2 `Request#net_http_object` and its `net.start { }` block),
    and `Station#internal_spotify_add_to_queue` in
    [app/models/station.rb](../app/models/station.rb).

    Rails does not boot on the owner's laptop: its Ruby 2.4 OpenSSL extension
    needs `libssl.so.1.1`, which current distributions no longer ship. Run the
    app and the test suite on the Pi.

  </details>

## Working on the Running Installation

- <details> <summary> <b>Working on the Running Installation</b> </summary>

    The Pi checkout at `/home/pi/jcradio` is the deployment. Rails runs in the
    development environment, so code changes under `app/` reload on the next
    request; changes to `config/initializers` or the Gemfile need a Rails restart
    (see [operations](operations.md)). Two settings in
    [config/environments/development.rb](../config/environments/development.rb)
    differ from Rails defaults on purpose: `eager_load = true` loads all of
    `app/` at boot (lazy autoloading raced when two requests arrived together
    after a restart), and `assets.debug = false` serves two concatenated asset
    bundles instead of 33 files. Both keep hot reloading.

    1. Edit and commit locally, push, then `git pull` on the Pi. For quick
       iteration, `scp` the changed files to the same paths and keep both trees
       at the same uncommitted state until you commit.
    2. Run the suite on the Pi. `-l` loads RVM and `-i` loads the Spotify
       environment variables from `.bashrc`:

       ```sh
       ssh jcradio-pi 'bash -lic "cd ~/jcradio && bin/rake test"'
       ```

    3. Never run `db:setup`, `db:reset`, `db:seed`, or migrations against
       `db/development.sqlite3` on the Pi without a fresh backup; it is the live
       history. The test suite uses `db/test.sqlite3`.
    4. Keep credential values out of commits and chat: the OAuth restore file,
       `SPOTIFY_CLIENT_*` values, and the player's `credentials.json`.

  </details>

## Where to Work

- <details> <summary> <b>Where to Work</b> </summary>

    | Question | First File to Read |
    | --- | --- |
    | Which URL invokes which action? | [Routes](../config/routes.rb) |
    | How is the default station established for each request? | [Application controller](../app/controllers/application_controller.rb) |
    | How does login work? | [Sessions controller](../app/controllers/sessions_controller.rb) |
    | Who is in line, whose turn is it, what is the letter? | [Station model](../app/models/station.rb) (`join`, `leave`, `advance_turn`, `next_letter`) |
    | How do selections reach Spotify and how does the queue follow it? | [Station model](../app/models/station.rb) (`queue_song`, `next_song`) and [stations controller](../app/controllers/stations_controller.rb) |
    | Where are the radio and personal Spotify logins kept? | [SpotifyAccounts](../lib/spotify_accounts.rb) and [jcradio initializer](../config/initializers/jcradio.rb) |
    | How does Buddy pick a song? | [Buddy](../app/models/buddy.rb) and [Buddy controller](../app/controllers/buddy_controller.rb) |
    | What are the title/letter rules? | [Songs helper](../app/helpers/songs_helper.rb) |
    | How are tracks found and cached? | [Song model](../app/models/song.rb) and [songs controller](../app/controllers/songs_controller.rb) |
    | What follows the player and updates timing? | [PlaybackPoller](../lib/playback_poller.rb) |
    | How do live browser events work? | [LiveRPC server](../lib/live-rpc.rb) and [client](../app/assets/javascripts/live-rpc.js.erb) |
    | Where are the navigation, sidebar, and player controls? | [Application layout](../app/views/layouts/application.html.erb) |
    | Where are the confirmation and override controls? | [Search-results partial](../app/views/songs/_search_results.html.erb) |
    | What data must survive a move? | [Schema](../db/schema.rb) and [data model](data-model.md) |
    | Why is a page slow? | [script/perf](../script/perf) and [performance characteristics](architecture.md#performance-characteristics) |

    The separate `html and css/` directory contains standalone design material
    that is not part of the routed Rails UI under `app/views` and `app/assets`.

  </details>

## Tests and Checks

- <details> <summary> <b>Tests and Checks</b> </summary>

    `bin/rake test` passes on the Pi as of 2026-09-14: 78 runs, 294 assertions.

    | File | Covers |
    | --- | --- |
    | [song_test.rb](../test/models/song_test.rb) | Search sends `limit: 10` and converts results |
    | [station_test.rb](../test/models/station_test.rb) | Queue POST success without JSON, 401 refresh-and-retry, persistent 401, other HTTP failures, dead pooled connection retried once, missing device, RSpotify `oauth_send` patch |
    | [station_turn_test.rb](../test/models/station_turn_test.rb) | Join/leave position shifting, current selector, turn advance and its broadcast, next-letter fallback and override, `songs_remaining`, `next_song` drift handling, Buddy setting defaults |
    | [buddy_test.rb](../test/models/buddy_test.rb) | Buddy's turn: waits when not his turn, alone with a full queue, or the queue is long; keeps his place when Spotify refuses; draws from played, upvoted, and linked-library tastes; concurrent callers skip |
    | [playback_poller_test.rb](../test/models/playback_poller_test.rb) | Background refresh runs off-thread one at a time; idle without a radio or playback; a new track advances the station; failures retry |
    | [player_watchdog_test.rb](../test/models/player_watchdog_test.rb) | Device list read; restart only when the device is missing; check and restart rate limits; recovery waits for the device; restart command from the environment, run without a shell |
    | [spotify_accounts_test.rb](../test/models/spotify_accounts_test.rb) | Linking, paged library fetch and cache, restore-file round trip, progress when idle |
    | [rest_client_keep_alive_test.rb](../test/models/rest_client_keep_alive_test.rb) | RestClient receives pooled connections, returns them after the request block or an exception, threads never share one, proxies bypass the pool |
    | [songs_controller_test.rb](../test/controllers/songs_controller_test.rb) | Library browse renders without persisting; history browse returns distinct songs newest-first per source; `current_user` is queried once per request |
    | [stations_controller_test.rb](../test/controllers/stations_controller_test.rb) | Queue JSON snapshot, human turn hand-off and broadcast, out-of-turn rejection, queue page defers the refresh to the poller |
    | [sessions_controller_test.rb](../test/controllers/sessions_controller_test.rb) | Login joins station 1 and refreshes the memoized user, unknown user, logout |
    | [users_controller_test.rb](../test/controllers/users_controller_test.rb) | Index/new/show render, create, duplicate, destroy rules |
    | [songs_helper_test.rb](../test/helpers/songs_helper_test.rb) | The letter-rules examples table; library conversion reads `preview_url` without a per-track Spotify request |

    Fixtures give station `one` the hard-coded `id: 1`. Tests stub HTTP with
    `Minitest::Mock`/`stub` and stub `LiveRPC.broadcast` to capture browser
    events; they never contact Spotify. Process state set in a test
    (`SpotifyAccounts.radio`, linked accounts) must be restored in `teardown`.
    Controller tests render the full layout, so a logged-in test needs a
    positioned queue entry and `station.queue_pos`, or the sidebar's letter
    strip does `nil` arithmetic.

    Dependency-light checks that run on any Ruby, from the repository root:

    ```sh
    ruby -Iapp/helpers -rsongs_helper -e 'raise unless SongsHelper.first_letter("The Radio") == "R"; raise unless SongsHelper.calculate_next_letter("Radio") == "A"; puts "Letter-rule probe passed"'
    ruby script/check-docs.rb
    ```

    The second checks documentation structure and local links against
    [the style guide](DOCS_STYLE_GUIDE.md).

    Performance checks live in [script/perf](../script/perf); none of them log
    in, write, or use a Spotify token:

    ```sh
    python3 script/perf/page-timings.py https://10.0.0.110:3000 /sessions /stations/1 /songs   # laptop: page + asset timings
    ssh jcradio-pi 'cd ~/jcradio && ruby script/perf/log-timings.rb log/development.log 2026-09-13'  # per-action p50/p90 from the log
    ssh jcradio-pi 'bash -lic "cd ~/jcradio && bin/rails runner script/perf/bench-inprocess.rb"'   # queries, helpers, rendering (40 s boot)
    ssh jcradio-pi 'bash -lic "cd ~/jcradio && bin/rails runner script/perf/bench-keepalive.rb"'   # Spotify connection reuse
    ssh jcradio-pi 'cd ~/jcradio && bash script/perf/sqlite-index-test.sh'                         # index trial on a DB copy
    ```

    `ruby` on the Pi means the RVM Ruby; the log script is plain Ruby. Baseline
    and current numbers are in
    [architecture](architecture.md#performance-characteristics).

    Useful next coverage: title edge cases beyond the documented examples,
    blank-queue startup, and the Spotify library browse path end to end.

  </details>
