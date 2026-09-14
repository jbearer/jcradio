User: I'd like to get an external expert review of this overall project to direct the next buckets of work for this project. Can you review the overall architecture and the documentation and the test structure just at a high level to give some feedback on how this project could improve, how it kind of rates against say a production level product, or some things that we should generally focus on to improve this project at the end of the day, I don't care about scaling this to thousands of users or anything, but I want to understand what good software paradigms should be adhered to, and whether the structure generally makes sense for the scope, I think reliability is important, not necessarily the scalability, but yeah, just get general feedback for if I were to share this kind of as a work sample I'd like to know how this would be received. So do some read only look at the repo, the documentation and write up a report based on your findings how good quality of a project is this and where could be the next optimizations or improvements to focus on

GitHub Copilot: Updated todo list

I'll start by checking my repository notes, then do a read-only survey of the codebase.

Read memory

Read

Read

Read

Read

Now the core code: models, controllers, and test layout.

Read

Read

Read , lines 1 to 300

Read , lines 1 to 120

Ran terminal command:  find test -type f | sort && echo "---LOC---" && wc -l app/models/*.rb app/controllers/*.rb app/helpers/*.rb lib/*.rb test/**/*.rb 2>/dev/null | sort -n | tail -30 && echo "---JS---" && find app/assets/javascripts -type f | xargs wc -l | tail -1 && echo "---VIEWS---" && find app/views -type f | wc -l && echo "---GIT---" && git --no-pager log --oneline | wc -l && git --no-pager log --oneline -8 && git --no-pager status --short | head -20 && echo "---CI---" && ls -a | grep -iE "github|gitlab|circle|travis|rubocop|editorconfig|dockerfile|procfile|ruby-version|tool-versions" ; echo "---migrations---" && ls db/migrate | wc -l

Read , lines 1 to 230

Read

Read

Read

Read

Read

Read

Read

Read , lines 1 to 120

Read

Ran terminal command:  echo "--- distinct globals ---" && grep -rhoE '\$[a-z_]+[a-zA-Z_]*' app lib config --include=*.rb --include=*.erb | sort | uniq -c | sort -rn | head -20 && echo "--- banner/debug log lines ---" && grep -rcE 'logger\.(error|info)\("\**"\)|logger\.(error|info)\("[*&$]{4,}' app lib | grep -v ':0' && echo "--- commented-out print lines ---" && grep -rcE '^\s*# print ' app | grep -v ':0' && echo "--- docs ---" && wc -l docs/*.md docs/pi/*.md | tail -1 && ls docs/pi && echo "--- js files ---" && ls app/assets/javascripts && echo "--- find_by username Buddy ---" && grep -rn 'username: "Buddy"' app | wc -l && echo "--- Station.find 1 / find(1) ---" && grep -rnE 'Station\.find\(? ?1\)?' app | wc -l

Searched for files matching `**/REVIEW*.md`, no matches

Created

Updated memory file

Report written to `REVIEW-project-2026-09-13.md`. Read-only; nothing else changed.

**Headline verdict:** a well-operated legacy hobby app in active recovery. The September work (root-caused fixes with regression tests, systemd units, cert automation, backups, evidence-labeled docs) is above what most small production teams do. The code body underneath is 2017–2020 student Rails and is what a reviewer sees first.

**Scorecard vs. a small-production bar**

| Area | Rating |
| --- | --- |
| Documentation | Strong |
| Operations / recoverability | Strong |
| Reliability engineering (recent) | Good |
| Code structure | Below bar |
| Test structure | Partial |
| Security posture | Hobby-grade, honestly stated |
| Dependency health | Poor (Ruby 2.4, Rails 4.2, Stretch all EOL) |

**Top structural issues** (details and evidence in the report)
1. 12 process globals; `$the_next_letter` referenced 29 times and derivable from the queue anyway.
2. Game logic in the wrong layer: 414-line `stations_controller.rb`, Buddy's algorithm in a controller action, turn-shifting loops copy-pasted five times, `TitleExtractorWorker` subclassing `ApplicationController` inside `stations_helper.rb`.
3. Production runs in `development` env: CSRF off, web-console, asset debug, class reloading on a Pi 3.
4. Tests cover Spotify edge cases well but zero coverage of turn order, letter rules table, `next_song` drift reconciliation, or Buddy; five empty scaffolds; Pi-only with no CI.
5. ~50 error-level banner logs and commented-out `print` blocks.

**Recommended buckets, in order**
1. Tests for the game rules + a `ruby:2.4.9` Dockerfile + GitHub Actions (`rake test`, `check-docs.rb`).
2. Remove globals: `next_letter`/Buddy settings onto `Station`, `RadioSpotifyAccount` class, persist personal refresh tokens on `User`, `Station.default`/`User.buddy`.
3. Move logic: `Station#join/leave/advance_turn`, `Buddy.choose`, poller as a plain class started from `after_initialize`.
4. Run like production: real env config, DB constraints, self-healing two-phase queue write, a station passphrase, confirm old client secret is rotated.
5. Write down the dependency decision: freeze-and-containerize, or staged upgrade gated by the suite.

**Work-sample framing:** lead with `docs`, the repair journal, `pi-recovery`, and the recent commits, and say plainly that the app body is inherited code you're stabilizing. A root `README.md` with that three-sentence story would do a lot for first impressions.

Created 3 todos

Made changes.

User: Okay, I created a new local branch to work on. There have been a couple more changes since your review, but nothing that changes the overall structure. Please address the issues, especially the globals and the radio logic. I don’t like calling this a game, so I changed all references from “game” to “radio.” Feel free to restart the radio as needed. The radio is currently running with just myself and Buddy. Verify that the tests still work after any rearchitectures. Feel free to create classes and generally make things cleaner. The functionality shouldn’t change, unless it improves it. Clean up the underlying code structure. I’ll step away for an hour; when I return, I’ll make sure the radio works as intended and that no bugs were introduced. Otherwise, have at it. Focus on the code structure. You can deploy to the Pi, but don’t commit anything—just copy it over. Have fun.

GitHub Copilot: Updated todo list

I'll start by checking the current branch state and re-reading the review file, then read every file I'll be touching before designing the refactor.

Ran terminal command:  git --no-pager status --short && git --no-pager branch --show-current && git --no-pager log --oneline -3 && git --no-pager diff --stat HEAD | tail -3

Ran terminal command:  git --no-pager diff --stat 7d5d97d HEAD | tail -40 && echo "--- globals now ---" && grep -rhoE '\$[a-z_]+[a-zA-Z_]*' app lib config --include=*.rb --include=*.erb --include=*.coffee | sort | uniq -c | sort -rn && echo "--- game refs ---" && grep -rniE '\bgame' app docs lib config test --include=*.rb --include=*.erb --include=*.md --include=*.js --include=*.coffee | head
Completed with input:  git --no-pager diff --stat 7d5d97d HEAD | tail -40 && echo "--- globals now ---" && grep -rhoE '\$[a-z_]+[a-zA-Z_]*' app lib config --include=*.rb --include=*.erb --include=*.coffee | sort | uniq -c | sort -rn && echo "--- game refs ---" && grep -rniE '\bgame' app docs lib config test --include=*.rb --include=*.erb --include=*.md --include=*.js --include=*.coffee | head

Read , lines 280 to 434

Read

Read

Read , lines 115 to 148

Read

Read

Read , lines 1 to 280

Read

Read

Searched for regex `\$(the_next_letter|spotify_user|client_spotifies|spotify_libraries_cached|buddy_on|buddy_taste|buddy_max_songs|notify_laggard_user|the_background_thread|buddy_last_add|refresh_thread|station|daniels_phone|JCRADIO_PI)` (`**/app/views/**`), 16 results

Searched for regex `\$(the_next_letter|spotify_user|client_spotifies|spotify_libraries_cached|buddy_on|buddy_taste|buddy_max_songs|notify_laggard_user|the_background_thread|buddy_last_add|refresh_thread|station|daniels_phone|JCRADIO_PI)` (`**/{app/controllers/chat_controller.rb,app/controllers/users_controller.rb,app/controllers/emojis_controller.rb,app/controllers/upvotes_controller.rb,app/controllers/notifications_controller.rb,app/models/**,config/**,lib/**,test/**}`), 37 results

Let me read the remaining files I'll touch: tests, views with globals, and the current station model.

Read

Read

Read

Read

Read

Read , lines 60 to 120

Read

Read

Read , lines 1 to 40

Read , lines 1 to 60

Read , lines 1 to 70

Read

Read

Read

Read

Read

Searched for regex `override|song_next_letter|one-word|mismatch` (`**/docs/letter-rules.md`), 5 results

Searched for regex `next_letter|song_next_letter` (`**/app/views/songs/_search_results.html.erb`), 7 results

Read , lines 1 to 60

Read , lines 76 to 105

Searched for regex `refresh|next_up|stations/1\.json|update_timing|next_song_js` (`**/app/assets/javascripts/**`), 30 results

Read

Read

Read

Searched for regex `refresh_now_playing\(|user-active|can_add_to_queue|subscribed\?|Magique|TitleExtractorWorker|perform_async` (`**/app/**`), 19 results

Read , lines 120 to 180

Read , lines 330 to 355

Read , lines 1 to 76

Read

Read

Before changing anything, let me establish a baseline on the Pi: test suite state, git parity, and a read-only look at user/station data my refactor will depend on.

Ran terminal command:  ssh jcradio-pi 'cd ~/jcradio && git --no-pager log --oneline -1 && git status --short && echo "--- users ---" && sqlite3 -header db/development.sqlite3 "select id, username, position, station_id from users order by id" && echo "--- stations ---" && sqlite3 -header db/development.sqlite3 "select id, name, queue_pos, now_playing_id from stations" && echo "--- last entries ---" && sqlite3 -header db/development.sqlite3 "select q.id, q.position, q.selector_id, s.title, s.next_letter from queue_entries q join songs s on s.id=q.song_id where q.position is not null order by q.position desc limit 3" && systemctl is-active jcradio-web jcradio-player'

Ran terminal command:  ssh jcradio-pi 'bash -lic "cd ~/jcradio && time bin/rake test 2>&1 | tail -4"'

Baseline: 46 runs / 182 assertions green. Let me record the plan in session memory, then start building.

Created memory file

Searched for regex `last_played` (`**/app/**`), 4 results

Searched for regex `/stations/1|Station\.find|users\.order\(:position\)|where\.not\(position: nil\)` (`**/app/views/**`), 12 results

Read , lines 64 to 80

Read , lines 1 to 50

Read

Now I have the full picture. Starting with the persistence layer: migration and the `Station` model.

Created

Read , lines 80 to 204

Now the rewritten `Station` model.

Created

Replacing 10 lines with 20 lines in


```

```


Created 5 todos

Replacing 32 lines with 123 lines in


```

```
Now replace `next_song` through the end of the file.

Replacing 106 lines with 52 lines in


```

```


Replacing 7 lines with 5 lines in


```

```
Now the two `lib` classes that hold process-level state (kept out of `app` so dev-mode reloads don't wipe them), and `Buddy`.

Created

Created

Completed: *Refactor global state and radio logic* (1/6)

Created

Created

Replacing 7 lines with 7 lines in


```

```
Now the controllers. `ApplicationController` first:

Replacing 41 lines with 10 lines in


```

```
Now `SessionsController`:

Replacing 119 lines with 51 lines in


```

```


Read , lines 1 to 10

Replacing 9 lines with 6 lines in


```

```
Now the big one — `StationsController`. I'll rewrite it top to bottom in sections.

Replacing 280 lines with 76 lines in


```

```


Updated todo list

Read , lines 74 to 220

Replacing 143 lines with 79 lines in


```

```


Read , lines 150 to 166

Replacing 15 lines with 7 lines in


```

```
Now `BuddyController`, `SongsController`, `RecommendationsController`, and the helpers.

Replacing 86 lines with 28 lines in


```

```


Replacing 3 lines with 3 lines in


```

```


Replacing 36 lines with 29 lines in ,


```

```

```

```


Searched for regex `msToMinSec|spotify_number_of_tracks|spotify_get_all_songs|StationsHelper|features\b` (`**/app/**`), 16 results

Now trim `RecommendationsHelper` to just `features`, and replace `StationsHelper` (whose only remaining content was the worker) with an empty helper module.

Replacing 42 lines with 4 lines in


```

```


Replacing 124 lines with 3 lines in

Read , lines 95 to 124

Read , lines 1 to 94

Replacing 124 lines with 3 lines in


```

```
Now `song.rb`, `user.rb`, and the views.

Replacing 6 lines with 6 lines in ,


```

```

```

```


Updated todo list

Replacing 29 lines with 30 lines in , , , , ,


```

```

```

```

```

```

```

```

```

```

```

```


Read , lines 1 to 20

Replacing 1 lines with 1 lines in


```

```
Now the sessions index view (replace the debug dump with a tidy status block):

Replacing 41 lines with 39 lines in


```

```
Let me verify no global references remain anywhere in app/lib/config, then move to tests.

Searched for regex `\$[a-zA-Z_]+|TitleExtractorWorker|Magique|refresh_now_playing_and_stuff|refresh_now_playing_in_background|buddy_add_song|spotify_get_all_songs|StationsHelper\.|Station\.find\(? ?1` (`**/{app,lib,config}/**`), 88 results

Only JavaScript `$` variables remain — all Ruby globals are gone. Now update the existing tests. Starting with `station_test.rb`:

Replacing 40 lines with 40 lines in


```

```


Read , lines 55 to 80

Replacing 4 lines with 4 lines in


```

```
Now `song_test.rb`, `songs_controller_test.rb`, `sessions_controller_test.rb`:

Replacing 50 lines with 43 lines in , ,


```

```

```

```

```

```


Replacing 136 lines with 104 lines in

Read , lines 118 to 140

Replacing 109 lines with 77 lines in


```

```
Now the new tests — turn order, letters, Buddy, the poller, and the accounts registry:

Created

Replacing 5 lines with 13 lines in


```

```


Created

Added 5 todos

Replacing 9 lines with 4 lines in


```

```
Now the poller, accounts, and letter-rule tests:

Created

Replacing 10 lines with 8 lines in


```

```


Created

Run in Terminal

Continue to iterate?
[object Object]

Updated todo list

Made changes.

User: @agent Continue: "Continue to iterate?"

GitHub Copilot: Ran terminal command:  ssh jcradio-pi 'G=$(ls -d /home/pi/.rvm/gems/ruby-2.4.9/gems/rspotify-2.9.2); sed -n "1,60p" $G/lib/rspotify/user.rb; echo "--- to_hash ---"; grep -n "to_hash\|def method_missing\|def respond_to" -A6 $G/lib/rspotify/base.rb | head -40; echo "--- player ---"; grep -n "def currently_playing\|def playing?\|def next\b" -A6 $G/lib/rspotify/player.rb | head -40'

Updated todo list

Ran terminal command:  ssh jcradio-pi 'G=/home/pi/.rvm/gems/ruby-2.4.9/gems/rspotify-2.9.2; grep -n "def initialize" -A25 $G/lib/rspotify/user.rb | head -45; echo "--- to_hash anywhere ---"; grep -rn "def to_hash" $G/lib/ ; echo "--- Base initialize ---"; grep -n "def initialize" -A12 $G/lib/rspotify/base.rb | head -20'

Replacing 2 lines with 22 lines in


```

```


Ran terminal command:  ruby -v && for f in app/models/station.rb app/models/buddy.rb app/models/song.rb app/models/user.rb lib/spotify_accounts.rb lib/playback_poller.rb config/initializers/jcradio.rb app/controllers/*.rb app/helpers/*.rb test/models/*.rb test/controllers/*.rb test/helpers/*.rb db/migrate/20260914000000_add_radio_state_to_stations.rb; do ruby -c "$f" >/dev/null || echo "FAIL $f"; done; echo syntax-done && git status --short

Right — Ruby 2.4 doesn't allow `ensure` directly in a `do` block (a lesson already in my notes). Fixing those two tests:

Replacing 23 lines with 27 lines in


```

```


Ran terminal command:  for f in test/models/*.rb; do ruby -c "$f" >/dev/null || echo "FAIL $f"; done; echo syntax-done; grep -rn "ensure" test/models/spotify_accounts_test.rb test/models/playback_poller_test.rb | head

Local syntax is clean. Now deploying: first a database backup, then the migration (columns are additive and harmless to the old code), then the code.

Ran terminal command:  ssh jcradio-pi 'mkdir -p ~/jcradio-recovery/2026-09-14 && cd ~/jcradio && sqlite3 db/development.sqlite3 ".backup ~/jcradio-recovery/2026-09-14/development-before-radio-state.sqlite3" && sqlite3 ~/jcradio-recovery/2026-09-14/development-before-radio-state.sqlite3 "pragma quick_check" && cp db/schema.rb ~/jcradio-recovery/2026-09-14/schema-before-radio-state.rb && ls -la ~/jcradio-recovery/2026-09-14/' && scp -q db/migrate/20260914000000_add_radio_state_to_stations.rb jcradio-pi:~/jcradio/db/migrate/ && ssh jcradio-pi 'bash -lic "cd ~/jcradio && bin/rake db:migrate 2>&1 | tail -8 && sqlite3 db/development.sqlite3 "pragma table_info(stations)" && git status --short"'

The sqlite `.backup` command doesn't expand `~`; using the full path.

Ran terminal command:  ssh jcradio-pi 'cd ~/jcradio && sqlite3 db/development.sqlite3 ".backup /home/pi/jcradio-recovery/2026-09-14/development-before-radio-state.sqlite3" && sqlite3 /home/pi/jcradio-recovery/2026-09-14/development-before-radio-state.sqlite3 "pragma quick_check" && cp db/schema.rb ~/jcradio-recovery/2026-09-14/schema-before-radio-state.rb && ls -la ~/jcradio-recovery/2026-09-14/' && scp -q db/migrate/20260914000000_add_radio_state_to_stations.rb jcradio-pi:~/jcradio/db/migrate/ && ssh jcradio-pi 'bash -lic "cd ~/jcradio && bin/rake db:migrate 2>&1 | tail -8 && sqlite3 db/development.sqlite3 "pragma table_info(stations)" && git status --short"'

Migration applied. Now pull the regenerated schema back and push the rest of the code over, then run the suite.

Ran terminal command:  scp -q jcradio-pi:~/jcradio/db/schema.rb db/schema.rb && git --no-pager diff db/schema.rb | grep "^[-+]" | grep -v "^[-+][-+]" && FILES=$(git status --short | awk '{print $2}' | grep -v REVIEW-project | grep -v '^db/migrate/' | grep -v '^db/schema.rb$') && echo "$FILES" | wc -l && tar cf - $FILES | ssh jcradio-pi 'cd ~/jcradio && tar xf - && git status --short'

Both trees match. Running the full suite on the Pi:

Ran terminal command:  ssh jcradio-pi 'bash -lic "cd ~/jcradio && bin/rake test 2>&1 | grep -v "^bash:" | tail -60"'

One test failure, and it's in the test itself: after Buddy's first turn, `@buddy` was a stale in-memory copy still at position 0, so `update!(position: 0)` was a no-op. Reloading first:

Replacing 7 lines with 7 lines in


```

```


Created 6 todos

Ran terminal command:  scp -q test/models/buddy_test.rb jcradio-pi:~/jcradio/test/models/buddy_test.rb && ssh jcradio-pi 'bash -lic "cd ~/jcradio && bin/rake test 2>&1 | grep -v "^bash:" | tail -6"'

78 runs / 294 assertions green (up from 46 / 182). Now restart Rails on the Pi so the new `lib` classes and initializer load, then verify the live site.

Ran terminal command:  ssh jcradio-pi 'bash -lic "jcradio-restart" 2>&1 | grep -v "^bash:" | tail -15'

Ran terminal command:  ssh jcradio-pi 'for i in $(seq 1 30); do code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 https://localhost:3000/stations/1.json); [ "$code" = "200" ] && break; sleep 3; done; echo "HTTP $code after $((i*3))s"; curl -sk --max-time 10 https://localhost:3000/stations/1.json | python3 -c "import sys,json; d=json.load(sys.stdin); print("next_user:", d["next_user"]["username"] if d["next_user"] else None, "next_letter:", d["next_letter"]); print(d["queue_html"][:300])"; echo "--- log ---"; grep -iE "error|exception|Now playing|Buddy|poll" ~/jcradio/log/development.log | tail -15'

Checked terminal output

Killed terminal

Ran terminal command:  ssh jcradio-pi 'cd ~/jcradio && ls -la log/development.log | awk "{print \$5}" && tail -n 4000 log/development.log | grep -iE "error|exception|Now playing|Buddy|poll|refresh failed" | grep -v "Cannot render console" | tail -20; echo "--- threads in rails ---"; pid=$(systemctl show -p MainPID --value jcradio-web); ls /proc/$pid/task | wc -l; echo "--- last requests ---"; tail -n 400 log/development.log | grep -E "^Started|^Completed" | tail -8'

Ran terminal command:  ssh jcradio-pi 'cd ~/jcradio && sqlite3 -header db/development.sqlite3 "select st.queue_pos, st.next_letter, st.buddy_taste, st.buddy_max_songs, q.position, s.title, s.duration, st.now_playing_start_ms, (strftime("%s","now")*1000 - st.now_playing_start_ms) as elapsed_ms from stations st join queue_entries q on q.id=st.now_playing_id join songs s on s.id=q.song_id" && date +%s && curl -sk -o /dev/null -w "HTML %{http_code} %{time_total}s\n" --max-time 20 https://localhost:3000/stations/1 && sleep 4 && sqlite3 db/development.sqlite3 "select now_playing_start_ms from stations" && tail -n 300 log/development.log | grep -iE "Now playing|Buddy|failed|Error" | tail -5'

Ran terminal command:  for t in test/javascripts/*.js; do node "$t" && echo "ok $t" || echo "FAIL $t"; done

Replacing 9 lines with 11 lines in ,


```

```

```

```


Ran terminal command:  ssh jcradio-pi 'curl -sk --max-time 20 https://localhost:3000/sessions | grep -oE "Radio Spotify: [A-Za-z ]+|Sign in for Radio Spotify Account|Next (up|letter)[^<]*" | head -5'

Ran terminal command:  tar cf - lib/playback_poller.rb config/initializers/jcradio.rb | ssh jcradio-pi 'cd ~/jcradio && tar xf - && bash -lic "jcradio-restart" 2>&1 | grep -E "Active:" ; for i in $(seq 1 30); do code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 https://localhost:3000/stations/1.json); [ "$code" = "200" ] && break; sleep 3; done; echo "HTTP $code after ~$((i*3))s"; tail -n 200 log/development.log | grep -E "PlaybackPoller|Radio Spotify account|No radio" '

Ran terminal command:  ssh jcradio-pi 'for p in /sessions /stations/1 /songs /buddy /recommendations /stations/1/plots /stations/1/change_queue_pos /chat /users /users/new "/songs/browse?source=all_songs&query=D" "/songs/inline_search?query=zombie"; do printf "%-45s " "$p"; curl -sk -o /dev/null -w "%{http_code} %{time_total}s\n" --max-time 30 -H "Accept: text/javascript, text/html" "https://localhost:3000$p"; done; echo "--- errors ---"; tail -n 1500 ~/jcradio/log/development.log | grep -E "Error|error|Exception" | grep -v "Cannot render console" | tail -5'

Ran terminal command:  ssh jcradio-pi 'curl -sk --max-time 20 https://localhost:3000/buddy | grep -oE "<th> [A-Za-z ]+ </th>|buddy_on: (true|false)|buddy_taste: [^<]*|value=[0-9]+ style" | tr -s " " | head -20; echo "--- sidebar ---"; curl -sk --max-time 20 https://localhost:3000/stations/1 | grep -oE "class="user(-active)?">\s*<td>[^<]+" | tr -s " \n" " "'

Ran terminal command:  ssh jcradio-pi 'curl -sk --max-time 20 https://localhost:3000/stations/1 | grep -A1 -E "class="user(-active)?"" | grep -oE "user(-active)?"|<td>[^<]+" | paste - - '

Live verification looks right: Austin (head of line) is highlighted, letter D derived correctly, Buddy settings persisted. Now the docs reference the old structure — let me find the stale spots.

Searched for regex `TitleExtractorWorker|\$spotify_user|\$client_spotifies|\$spotify_libraries_cached|\$the_next_letter|global|Process globals|buddy_add_song|refresh_now_playing|stations_helper|StationsHelper|Magique|24 runs|46 runs|Station\.find|hard-coded|nothingtoseehere` (`**/docs/*.md`), 17 results

Read , lines 48 to 160

Read , lines 100 to 130

Read , lines 20 to 35

Now the doc updates, keeping to the style guide (details blocks, same voice):

Replacing 68 lines with 84 lines in , , ,


```

```

```

```

```

```

```

```


Read , lines 64 to 125

Read , lines 125 to 140

Replacing 28 lines with 36 lines in


```

```


Searched for regex `runs, \d+ assertions|\| \[Station\]\(\.\./app/models/station\.rb\)|Tests:\*\*` (`**/docs/*.md`), 4 results

Replacing 3 lines with 3 lines in , ,


```

```

```

```

```

```


Read , lines 96 to 105

Replacing 7 lines with 12 lines in


```

```


Updated todo list

Ran terminal command:  ruby script/check-docs.rb 2>&1 | tail -4

Docs lint passes. Let me mirror the doc changes to the Pi and confirm every changed file is byte-identical on both sides.

Ran terminal command:  FILES=$(git status --short | awk '{print $2}' | grep -v REVIEW-project) && tar cf - $FILES | ssh jcradio-pi 'cd ~/jcradio && tar xf -' && (for f in $FILES; do md5sum "$f"; done) > /tmp/local.md5 && ssh jcradio-pi "cd ~/jcradio && for f in $(echo $FILES | tr '\n' ' '); do md5sum "\$f"; done" > /tmp/pi.md5 && diff /tmp/local.md5 /tmp/pi.md5 && echo "PARITY OK: $(wc -l < /tmp/local.md5) files" && ssh jcradio-pi 'cd ~/jcradio && git status --short | wc -l' && git status --short | grep -v REVIEW | wc -l

Ran terminal command:  diff <(awk '{print $1, $2}' /tmp/local.md5) <(tr -d '\r' < /tmp/pi.md5 | awk 'NF{print $1, $2}') && echo "PARITY OK: $(wc -l < /tmp/local.md5) files"; ssh jcradio-pi 'cd ~/jcradio && git status --short | wc -l'; git status --short | grep -v REVIEW | wc -l

Ran terminal command:  cat -A /tmp/pi.md5 | head -2; echo ---; cat -A /tmp/local.md5 | head -1; echo "--- mismatched hashes (ignoring formatting) ---"; comm -3 <(awk '{print $1}' /tmp/local.md5 | sort) <(tr -d '\r' < /tmp/pi.md5 | awk 'NF{print $1}' | sort) | wc -l

Ran terminal command:  comm -3 <(awk '{print $1, $2}' /tmp/local.md5 | sort) <(tr -d '\r' < /tmp/pi.md5 | sed 's/^[^0-9a-f]*//' | awk 'NF{print $1, $2}' | sort)

All 43 files match (the only diff line is a terminal escape prefix on the Pi's first output line). Let me check whether Node exists on the Pi to run the JS view tests, then wrap up.

Ran terminal command:  ssh jcradio-pi 'command -v node nodejs || echo "no node"; cd ~/jcradio && for t in test/javascripts/*.js; do if command -v node >/dev/null; then node "$t" && echo "ok $t"; elif command -v nodejs >/dev/null; then nodejs "$t" && echo "ok $t"; fi; done'

JS tests pass too. Recording what was done in memory, then a final state check.

Updated memory file

Ran terminal command:  git --no-pager diff --stat | tail -1; echo "--- new files ---"; git status --short | grep '^??'; echo "--- pi ---"; ssh jcradio-pi 'cd ~/jcradio && git --no-pager log --oneline -1 && systemctl is-active jcradio-web jcradio-player && curl -sk --max-time 10 https://localhost:3000/stations/1.json | python3 -c "import sys,json; d=json.load(sys.stdin); print("next_user:", d["next_user"]["username"], "letter:", d["next_letter"])" && tail -n 800 log/development.log | grep -E "playback poll failed|background refresh failed|Error" | grep -v "Cannot render" | wc -l'

Done. The refactor is deployed to the Pi (uncommitted on both sides, trees byte-identical), Rails restarted, radio state intact: Austin's turn, letter D, both services active, zero errors in the log.

## What changed

**All 13 process globals are gone.** State now lives where it belongs:

| Was | Now |
| --- | --- |
| `$the_next_letter`, `$buddy_taste`, `$buddy_max_songs` | Columns on `stations` (migration run after a DB backup in `~/jcradio-recovery/2026-09-14/`). `next_letter` falls back to the last queued song's letter when unset. |
| `$spotify_user`, `$client_spotifies`, `$spotify_libraries_cached` | `spotify_accounts.rb` — radio account (restore file, sign in/out), linked accounts, library cache, device ID (`JCRADIO_SPOTIFY_DEVICE_ID` env override) |
| `TitleExtractorWorker`/`Magique` (in a helper, subclassing `ApplicationController`), `$the_background_thread`, `$refresh_thread`, `$notify_laggard_user` | `playback_poller.rb` — started at boot by `jcradio.rb` |
| `buddy_add_song` (150 lines in the controller), `$buddy_on`, `$buddy_last_add` | `buddy.rb` — `Buddy.take_turn(station)` with a lock instead of a 5-second timer |
| Five copy-pasted position-shifting loops | `Station#join`, `#leave`, `#advance_turn`, `#current_selector`, `#turn?`, `#announce_turn` in `station.rb` |
| `Station.find 1` ×8, `"Buddy"` ×5 | `Station.default`, `Buddy::USERNAME` |

`stations_controller.rb` went from 414 to ~155 lines; ~50 banner log lines and the commented-out `print` blocks are gone. Net: 34 files, +404/−949.

**Tests:** 78 runs / 294 assertions green on the Pi (was 46 / 182). New: turn order, letter fallback/override, `next_song` drift, Buddy's every branch, the poller, the accounts registry, and the letter-rules examples table from the docs. JS view tests also pass on the Pi. Docs updated; lint OK.

## Behavior changes to check when you're back

Things that improved rather than stayed identical:

1. **Buddy also acts from the poller loop while music plays**, not only on page loads — so he answers his turn within a second or two and refills the queue when alone, instead of waiting for someone to load a page. A silent radio still needs a page load to start.
2. **Buddy samples distinct songs.** The old `.uniq` result was discarded, so often-played songs were weighted heavier.
3. **Sidebar highlight** now follows the actual head of the line (it compared `position == 0`, which never matched after the first song — your position is 63).
4. **Radio account restores and the poller starts at boot**, not on the first home-page visit (log lines: `Radio Spotify account restored`, `PlaybackPoller started`).
5. Buddy's taste page lists everyone who has ever selected a song instead of a hard-coded six names.
6. Library fetch starts at offset 0 (it skipped your first saved track); Buddy's Spotify taste no longer writes the whole library to the DB, only the chosen song.
7. "Save to library" no longer 500s after succeeding (a `DoubleRenderError`); the home page's debug dump is replaced by a one-line "Linked Spotify accounts" list; the unrouted `stations#next` action is removed.

I did not add a song to the live queue — the radio is idle with nothing remaining, and adding one would have started playback while you were out.

Completed: *Implement new SpotifyAccounts and PlaybackPoller classes* (1/7)

Made changes.
