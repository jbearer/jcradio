# Development and Code Map

## Historical Toolchain

- <details> <summary> <b>Historical Toolchain</b> </summary>

    | Component | Repository Evidence |
    | --- | --- |
    | Ruby 2.4.9 | [Original setup notes](../README.rdoc) |
    | Rails 4.2.8 | [Gemfile](../Gemfile) |
    | Bundler 1.17.3 | [Lockfile](../Gemfile.lock) |
    | RSpotify 2.9.2, omniauth-oauth2 1.3.1 | [Lockfile](../Gemfile.lock) |
    | SQLite, Puma, Sass, CoffeeScript, jQuery, Turbolinks | [Gemfile](../Gemfile) |
    | JavaScript runtime | Original README notes that Node.js was needed on one Ubuntu setup |

    These are legacy versions, not a recommended new public-server stack. A modern
    Ruby installation being able to execute a helper does not mean it can boot
    Rails 4.2 and all of these dependencies.

    The original README specifically warns against an omniauth-oauth2 update that
    broke the old RSpotify integration. Preserve the lockfile while reproducing
    the baseline; do not start recovery with an unrestricted dependency update.

   The [Pi inspection](pi/inspection-2026-09-12.md) found RVM Ruby 2.4.9 and a
   matching legacy lockfile. Its deployed checkout has three uncommitted changes
   to the player-start/restart control. Preserve those differences before using
   the local checkout as a reproduction baseline.

  </details>

## Reproduction Sequence

- <details> <summary> <b>Reproduction Sequence</b> </summary>

    1. Preserve the Pi's data and configuration using the [recovery checklist](operations.md).
    2. Work on an isolated checkout and a database copy. Confirm the intended
       Rails environment and database path before any database task.
    3. Reproduce the historical Ruby/Bundler environment, following the original
       README as evidence rather than assuming those install steps still work on
       current Linux. Record OS and native-library issues as they arise.
    4. Run `bundle check`; install missing dependencies in that isolated environment
       when ready. Keep credential values out of the repository and logs shared here.
    5. Inspect the station/user/queue assumptions before initializing a blank
       database. The seeds are incomplete for production and empty-queue startup
       needs testing.
    6. Once the environment and test database are safe, try `bundle exec rake test`
       and record the baseline failures.
    7. Start a local-only instance with `bundle exec rails server -b 127.0.0.1`.
       Verify pages and session behavior before enabling external playback.

    The old `rake db:setup` and `rake db:migrate` instructions are not permission to
    run them on the only existing database. No full installation or server boot
    was attempted during this documentation pass.

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

    The separate `html and css/` directory contains standalone design material.
    The routed Rails UI inspected here lives under `app/views` and `app/assets`;
    the standalone material's historical role still needs confirmation.

  </details>

## Verification Status

- <details> <summary> <b>Verification Status</b> </summary>

    The initial documentation pass checked eight title-rule examples directly
    against `SongsHelper`, without booting Rails or calling Spotify, and checked
    local Markdown link targets. It did not run the Rails suite, exercise the UI,
    contact the historical host, or verify the audio stream.

   A later read-only SSH pass inspected the Pi and queried Icecast status.
   It did not start Rails, play audio, contact Spotify APIs, or run the Rails
   tests. The owner confirmed the radio is currently stopped. See
   [Pi overview](pi-overview.md) for current evidence rather than assuming the
   earlier repository-only uncertainty still applies.

    Most core model/controller tests contain only commented scaffold examples.
    Some user/session tests contain executable assertions; their current validity
    has not been established. See [the test helper](../test/test_helper.rb),
    [station tests](../test/controllers/stations_controller_test.rb), and
    [user tests](../test/controllers/users_controller_test.rb).

    A cheap, dependency-light rule probe from the repository root is:

    ```sh
    ruby -Iapp/helpers -rsongs_helper -e 'raise unless SongsHelper.first_letter("The Radio") == "R"; raise unless SongsHelper.calculate_next_letter("Radio") == "A"; puts "Letter-rule probe passed"'
    ```

    Next useful automated coverage would target title edge cases, wrong-turn
    rejection, blank-queue startup, queue drift, and persistence/restart behavior.
    That testing work is separate from this documentation-only change.

  </details>
