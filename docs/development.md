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
    RSpotify integration; keep the lockfile pinned. Two places depend on RSpotify
    2.9.2 internals and must be re-checked if the gem is ever bumped:
    [config/initializers/rspotify_token_refresh.rb](../config/initializers/rspotify_token_refresh.rb)
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
    (see [operations](operations.md)).

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
    | How are the shared station and globals established? | [Application controller](../app/controllers/application_controller.rb) |
    | How does login or Spotify restoration work? | [Sessions controller](../app/controllers/sessions_controller.rb) |
    | How do turns advance and controls invoke Spotify? | [Stations controller](../app/controllers/stations_controller.rb) |
    | How does the local queue follow Spotify? | [Station model](../app/models/station.rb) |
    | What are the title/letter rules? | [Songs helper](../app/helpers/songs_helper.rb) |
    | How are tracks found and cached? | [Song model](../app/models/song.rb) and [songs controller](../app/controllers/songs_controller.rb) |
    | What updates playback timing? | [Stations helper and polling worker](../app/helpers/stations_helper.rb) |
    | How do live browser events work? | [LiveRPC server](../lib/live-rpc.rb) and [client](../app/assets/javascripts/live-rpc.js.erb) |
    | Where are the navigation, sidebar, and player controls? | [Application layout](../app/views/layouts/application.html.erb) |
    | Where are the confirmation and override controls? | [Search-results partial](../app/views/songs/_search_results.html.erb) |
    | What data must survive a move? | [Schema](../db/schema.rb) and [data model](data-model.md) |

    The separate `html and css/` directory contains standalone design material
    that is not part of the routed Rails UI under `app/views` and `app/assets`.

  </details>

## Tests and Checks

- <details> <summary> <b>Tests and Checks</b> </summary>

    `bin/rake test` passes on the Pi as of 2026-09-13: 24 runs, 90 assertions.
    Coverage is intentionally narrow:

    | File | Covers |
    | --- | --- |
    | [song_test.rb](../test/models/song_test.rb) | Search sends `limit: 10` and converts results |
    | [station_test.rb](../test/models/station_test.rb) | Queue POST success without JSON, 401 refresh-and-retry, persistent 401, other HTTP failures, missing device, RSpotify `oauth_send` patch |
    | [songs_controller_test.rb](../test/controllers/songs_controller_test.rb) | Library browse renders without persisting |
    | [sessions_controller_test.rb](../test/controllers/sessions_controller_test.rb) | Login joins station 1, unknown user, logout |
    | [users_controller_test.rb](../test/controllers/users_controller_test.rb) | Index/new/show render, create, duplicate, destroy rules |

    Fixtures give station `one` the hard-coded `id: 1`. Tests stub HTTP with
    `Minitest::Mock`/`stub`; they never contact Spotify.

    Dependency-light checks that run on any Ruby, from the repository root:

    ```sh
    ruby -Iapp/helpers -rsongs_helper -e 'raise unless SongsHelper.first_letter("The Radio") == "R"; raise unless SongsHelper.calculate_next_letter("Radio") == "A"; puts "Letter-rule probe passed"'
    ruby script/check-docs.rb
    ```

    The second checks documentation structure and local links against
    [the style guide](DOCS_STYLE_GUIDE.md).

    Useful next coverage: title edge cases, wrong-turn rejection, blank-queue
    startup, queue drift, and Buddy's selection.

  </details>
