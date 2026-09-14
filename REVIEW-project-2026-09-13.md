# JC Radio: External Project Review

Date: 2026-09-13. Scope: read-only review of architecture, documentation, and
test structure on branch `atc/dev` (HEAD `7d5d97d` plus uncommitted perf work).
Nothing was changed. Target bar: a small, reliable, single-host service used by
a handful of people, not a horizontally scaled product.

## Snapshot

| Dimension | Observed |
| --- | --- |
| Size | ~2,850 lines Ruby (app + lib + tests), ~1,100 lines JS/Coffee, 33 views, 30 migrations, 257 commits |
| Stack | Ruby 2.4.9, Rails 4.2.8, SQLite, Puma 4, RSpotify 2.9.2 (pinned, monkey-patched), jQuery + CoffeeScript |
| Host | One Raspberry Pi 3B on Raspbian Stretch; Rails runs in the `development` environment as a systemd service |
| Tests | 7 real test files, ~31 runs / ~106 assertions, runnable only on the Pi |
| Docs | 14 Markdown pages (~2,600 lines) with a style guide and a lint script |

## Overall Assessment

This is a well-operated legacy hobby application in active recovery. The
recent work (September 2026) is disciplined and would be received well: every
bug fix has a root-cause explanation and a regression test, the operations
story is complete (systemd units, restart/status/log helpers, cert automation,
backups before every change), and the documentation is unusually honest about
what is verified versus inferred.

The code body underneath is 2017-2020 student-project Rails: process-global
mutable state, a 400-line controller holding radio logic, a background thread
subclassing `ApplicationController` inside a helper file, and a production
deployment that runs in `development` mode. None of that is unusual for a
project of this origin, but it is what a reviewer sees first when opening
`app/`.

Scorecard against a small-production bar:

| Area | Rating | One-line reason |
| --- | --- | --- |
| Documentation | Strong | Evidence labels, current-state vs historical split, code anchors, open-items table, lint script |
| Operations / recoverability | Strong | Units, shell helpers, cert hook, backups, recovery scripts, dated journals |
| Reliability engineering (recent) | Good | Root-caused 401/429/BusyException/N+1, regression test per fix, WAL, measured perf |
| Code structure | Below bar | 12 globals, fat controller, logic in helpers, duplicated turn logic, hard-coded singletons |
| Test structure | Partial | Good coverage of Spotify edge cases; zero coverage of the core radio rules; five empty scaffolds; Pi-only |
| Security posture | Hobby-grade, honest | Username-only login, CSRF off (because dev env), public HTTPS endpoint |
| Dependency health | Poor | Ruby, Rails, OS, and sqlite3 gem all EOL; two dependencies on private gem internals |

As a work sample: lead with the recovery narrative (docs, journals, recent
commits, `script/pi-recovery/`), and state plainly that the app body is
inherited code being stabilized. That framing turns the code age from a
liability into the setup for the story. Without the framing, a reviewer who
opens `stations_controller.rb` first will form a different opinion.

## What Is Good and Worth Keeping

- **Docs discipline.** `docs/README.md` separates Current State, Open Items,
  and Code Anchors. Pages carry "Verified in code / Verified on Pi / Owner
  context / Inference" labels. Historical pages are banner-marked and frozen.
  `script/check-docs.rb` enforces structure and links. This exceeds what most
  production teams maintain.
- **Operations as code.** `script/pi-recovery/` holds the systemd units, the
  shell functions `~/.bashrc` sources, and the certbot deploy hook. The Pi's
  state is reproducible from the repo plus one env file.
- **Root-cause culture.** The 429 fix traced a lazy `method_missing` fetch on a
  now-null `preview_url`; the BusyException fix identified `journal_mode=delete`
  rather than adding retries; the N+1 work measured 722 queries -> 0. Comments
  in `song.rb` and `station.rb` explain *why*, including which pinned gem
  internals are being relied upon.
- **`lib/live-rpc.rb`.** Small, documented, correct use of `Mutex` +
  `ConditionVariable`, keeps unsent messages on disconnect, cleans up at exit.
  This is the best-structured code in the repo and shows what the rest could
  look like.
- **Test style where it exists.** `station_test.rb` stubs `RestClient` at the
  boundary, asserts on request sequences, and restores global state in
  `teardown`. Tests never contact Spotify.
- **Secrets mostly handled.** Client ID/secret via `ENV.fetch` with no
  fallback; OAuth restore file outside the repo; `.gitignore` covers WAL/SHM.

## What Holds It Back

Ordered by how quickly a reviewer would notice and how much reliability it costs.

### 1. Process-global mutable state

Twelve `$globals`; `$the_next_letter` alone appears 29 times. `$spotify_user`,
`$client_spotifies`, `$spotify_libraries_cached`, `$buddy_*`,
`$notify_laggard_user`, `$buddy_last_add` are read and written from Puma request
threads, the polling thread, and SSE threads with no synchronization.

Costs: personal Spotify links and the current letter vanish on restart; tests
must save/restore globals by hand; the next letter can disagree with the queue
(the `"_"` sentinel checks in `stations#show` and `sessions#create` exist to
repair exactly that); nothing can run as more than one process. The next letter
is fully derivable from the last positioned `QueueEntry`'s `song.next_letter`,
so the global is redundant state.

### 2. Domain logic in the wrong layer

- `StationsController` is 414 lines. `buddy_add_song` (~150 lines) is Buddy's
  entire selection algorithm living in a controller, untestable without a
  request.
- Turn-order maintenance (shift everyone's `position`, append at the back) is
  copy-pasted in `sessions#create` (twice), `sessions#destroy`, `stations#update`,
  and `buddy_add_song`.
- `TitleExtractorWorker` is a `class ... < ApplicationController` defined in
  `app/helpers/stations_helper.rb`, wrapped in a hand-rolled `Magique::Worker`
  thread mixin, and started as a side effect of rendering the home page.
- Hard-coded singletons: `Station.find 1` (8 sites), `User.find_by(username:
  "Buddy")` (5 sites), `$JCRADIO_PI` device ID as a global constant at the
  bottom of `station.rb`, `$daniels_phone` at the bottom of a helper.

### 3. Production runs in `development`

The Pi's systemd unit runs Rails in the development environment. That gives
hot reloading (convenient for scp fixes) at the cost of: CSRF protection
disabled by `skip_before_action :verify_authenticity_token`, `web-console`
attempting to render on every error (157k log lines), asset debug mode (~33
requests and ~100 ms per page), per-request class reloading on a Pi 3, and the
live database named `development.sqlite3`. This is the single loudest
"not production" signal in the repo.

### 4. Debug residue

Roughly 50 `logger.error("****...")` banner lines, `logger.error` used for
normal-flow tracing (`next_song` emits six error-level banners per track
change), and blocks of commented-out `print` statements. Reviewers read this as
unfinished; operationally it buries real errors.

### 5. Tests cover the edges, not the core

What is tested: Spotify search limit, queue POST body handling, 401 refresh,
missing device, library browse not persisting, login/logout, users CRUD, one
letter-helper regression.

What is not tested: turn order (join, leave, wrong-turn rejection, position
shifting), the letter rules beyond one case (eight documented examples in
`letter-rules.md` are a ready-made table), `Station#next_song` drift
reconciliation, Buddy selection, the polling loop's state machine. These are
the pure-logic parts of the product and the cheapest to test.

Five files are empty scaffolds (`stations_controller_test.rb`,
`notification_test.rb`, `user_test.rb`, `chat_test.rb`, `database_test.rb`).
There is no CI, and the suite cannot run on the development laptop because
Ruby 2.4's OpenSSL needs `libssl.so.1.1`. The docs also already drift on hard
numbers (README says 24 runs / 90 assertions; the suite is now ~31 / ~106).

### 6. Authentication and exposure

Login is a username with no credential. Combined with a public HTTPS endpoint,
CSRF disabled, and `cookies[:current_user]` rewriting user JSON into a plain
cookie on every request, anyone who finds the hostname can join and control the
queue. The docs state this honestly. For friends-only use it is a choice; for a
work sample it needs to be stated as a choice with a named mitigation.

`YAML.load_file` on the OAuth restore file deserializes arbitrary Ruby objects.
The file is owner-written so the risk is low, but a reviewer will flag it.

### 7. Data integrity

- Two-phase write: Spotify queue POST succeeds, then `QueueEntry.create`. If
  the second fails the song plays but the turn is not consumed. WAL mode
  reduced the window; it did not remove it. A compensating step (log + mark
  drift, or retry the local write) would close it.
- No `null: false` on foreign keys, no unique index on `songs(source,
  source_id)` or `users.username`, no FK constraints. SQLite supports all of
  these; the current data would need a one-time cleanup first.
- Vestigial `chats` and `sessions` tables; `Trigram` class defined inside
  `song.rb`.

### 8. Dependency end-of-life

Ruby 2.4 (EOL 2020), Rails 4.2 (EOL 2017), Raspbian Stretch (EOL 2020),
sqlite3 gem 1.3.x. Two code paths reach into RSpotify 2.9.2 private methods
(`oauth_header`, `refresh_token`, `oauth_send`). No security patches are
available for any layer. The practical exposure is LAN plus Spotify tokens,
which is bounded, but this is the first question any reviewer asks.

### 9. Housekeeping

Root directory has `dictate.txt`, `notes.txt`, an `html and css/` folder with
spaces in the name, and a default `README.rdoc` rather than a `README.md`
pointing at `docs/`. `routes.rb` retains 60 lines of Rails-generator comments.
Frontend mixes CoffeeScript, `.js.erb`, plain JS, jQuery, and a vendored
`skel.min.js`. None of this affects reliability; all of it affects first
impressions.

## Recommended Buckets of Work

Ordered for reliability. Each bucket is independently shippable; earlier
buckets make later ones safer.

### Bucket 1: Lock in the rules with tests, and make tests runnable anywhere

- Table-driven tests for `SongsHelper.first_letter` and
  `calculate_next_letter` using the examples in `docs/letter-rules.md`.
- Turn-order tests: join appends to the back, leave closes the gap, the head
  user can add, others are rejected, Buddy is skipped in "next up" logic.
- `Station#next_song` reconciliation with in-memory `QueueEntry` fixtures:
  expected song at head, song further down (drift), song absent (unpositioned
  entry).
- Buddy selection given a letter and each `taste` source, with `rand` stubbed.
- Delete or fill the five empty scaffolds.
- Add a `Dockerfile` on `ruby:2.4.9` so `bin/rake test` runs off the Pi; add a
  GitHub Actions workflow running `bin/rake test` and `ruby
  script/check-docs.rb` on every push.

Why first: everything below is refactoring, and refactoring without tests on
the core rules is how a friends-only radio breaks on a Friday night.

### Bucket 2: Remove process-global state

- `$the_next_letter` -> `Station#next_letter`, derived from the last positioned
  entry (or a column updated in the same transaction as the `QueueEntry`).
- `$buddy_on`, `$buddy_taste`, `$buddy_max_songs`, `$buddy_last_add` ->
  columns on `Station` (or a small `buddy_settings` table). Survives restart,
  testable, no sentinel checks.
- `$spotify_user` -> a `RadioSpotifyAccount` class with `load`, `save`,
  `clear`, and a path from config; `YAML.safe_load` with an explicit
  permitted-classes list, or persist only the fields RSpotify needs.
- `$client_spotifies` / `$spotify_libraries_cached` -> persist each user's
  refresh token on `User` so personal links survive restarts; cache library
  results with a TTL in `Rails.cache`.
- Introduce `Station.default` and `User.buddy`; move the Pi device ID to
  `ENV`/`secrets.yml`.

### Bucket 3: Move logic to models and plain classes

- `Station#join(user)`, `Station#leave(user)`, `Station#advance_turn`, and
  `Station#current_selector` replace the five copy-pasted position loops.
- `buddy_add_song` -> `Buddy.choose(station, letter)` returning a song, with
  the controller reduced to "call it, queue it, advance".
- `TitleExtractorWorker` -> `lib/playback_poller.rb`, a plain class started from
  `config.after_initialize` (guarded so tests and rake tasks do not start it),
  not from the home page.
- Replace banner logging with `logger.debug` under a tag, and reserve
  `logger.error` for failures. Delete commented-out `print` blocks.

### Bucket 4: Run it like production

- A `production` (or `pi`) environment: `cache_classes`, `eager_load`,
  precompiled assets, CSRF enabled, `web-console` removed, log level from
  `ENV`. Keep the `scp`-and-reload workflow by using `jcradio-restart`, which
  already exists.
- Migration adding `null: false`, `unique` on `songs(source, source_id)` and
  `users.username`, after a backup and one-time duplicate check.
- Make "queue on Spotify, then record locally" self-healing: if the local
  write fails, log with the Spotify request ID and let the poller's
  drift-reconciliation create the entry with the right selector.
- Add a shared station passphrase (one `has_secure_password` on `Station`, or
  a single env-provided token) so the public endpoint is not open to anyone.
- Confirm the old Spotify client secret from git history has been rotated.

### Bucket 5: Decide the dependency strategy explicitly

Two defensible options; pick one and write it in `docs/development.md`:

- **Freeze and contain.** Keep Ruby 2.4 / Rails 4.2, run tests and the app in
  the Docker image, document the risk boundary (LAN + Spotify tokens + Pi).
  Cheapest; honest.
- **Incremental upgrade.** Only after Bucket 1. Order: Rails 4.2 -> 5.2 on
  Ruby 2.5/2.6, then Rails 6.1 on Ruby 2.7, then Rails 7.x on Ruby 3.x.
  Each step gated by the suite. Replace Fuzzily and the RSpotify monkey-patches
  along the way. Substantial, but it removes the "everything is EOL" opener.

### Small, high-visibility cleanups (do any time)

- Add a root `README.md` that links to `docs/README.md` and states the
  "inherited, restored, stabilized" story in three sentences.
- Remove generator comments from `routes.rb`; move `dictate.txt` and
  `html and css/` out of the root or into `docs/design/`.
- Fix the drifted test counts in `docs/README.md` and `docs/development.md`,
  or replace them with "see CI".

## Closing

The project already does the hard part of small-scale reliability well: it is
observable, restartable, backed up, and documented with evidence levels. The
remaining gap is structural, not operational. Tests on the radio rules, then
removing globals, then moving logic out of controllers would bring the code
body up to the standard the docs and recent commits already meet. Deciding the
dependency strategy explicitly removes the last easy objection from any reader.
