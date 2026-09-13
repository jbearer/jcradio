#!/bin/bash
# Time the hot SQLite queries on a throwaway COPY of the dev DB, before/after candidate indexes.
# Usage (on the Pi): bash script/perf/sqlite-index-test.sh [db/development.sqlite3]
set -e
SRC=${1:-db/development.sqlite3}
DB=$(mktemp /tmp/perf-copy-XXXXXX.sqlite3)
trap 'rm -f "$DB"' EXIT
cp "$SRC" "$DB"
sqlite3 "$DB" "PRAGMA journal_mode=delete;" >/dev/null

IDS=$(sqlite3 "$DB" "select group_concat(quote(source_id)) from (select source_id from songs order by id limit 500)")
declare -A Q
Q[source_id_in_500]="select id from songs where source_id in ($IDS)"
Q[browse_join_S_limit500]="select songs.* from queue_entries inner join songs on songs.id=queue_entries.song_id where queue_entries.position is not null and songs.first_letter='S' order by queue_entries.id desc limit 500"
Q[browse_distinct_songs_S]="select songs.* from songs inner join queue_entries on queue_entries.song_id=songs.id where queue_entries.position is not null and songs.first_letter='S' group by songs.id order by max(queue_entries.id) desc limit 500"
Q[queue_max]="select max(position) from queue_entries where station_id=1 and position is not null"
Q[queue_before]="select * from queue_entries where station_id=1 and position is not null and position >= 11100 order by position"
Q[find_by_source_id]="select * from songs where source='Spotify' and source_id=(select source_id from songs order by id desc limit 1) limit 1"

run_all() {
  for name in "${!Q[@]}"; do
    # 20 iterations to get above timer resolution
    t0=$(date +%s%N)
    for i in $(seq 20); do sqlite3 "$DB" "${Q[$name]}" >/dev/null; done
    t1=$(date +%s%N)
    printf "  %-28s %6.1f ms/query\n" "$name" "$(awk -v a="$t0" -v b="$t1" 'BEGIN{print (b-a)/1e6/20}')"
  done | sort
}

echo "== before indexes"; run_all
sqlite3 "$DB" "create index idx_songs_source_id on songs(source_id);
create index idx_songs_first_letter on songs(first_letter);
create index idx_qe_song_id on queue_entries(song_id);
create index idx_qe_station_id on queue_entries(station_id);"
echo "== after indexes (source_id, first_letter, qe.song_id, qe.station_id)"; run_all
echo "  (each number includes ~sqlite3 CLI startup; compare relative)"
t0=$(date +%s%N)
for i in $(seq 20); do sqlite3 "$DB" 'select 1' >/dev/null; done
t1=$(date +%s%N)
printf "  %-28s %6.1f ms\n" "cli_startup_baseline" "$(awk -v a="$t0" -v b="$t1" 'BEGIN{print (b-a)/1e6/20}')"
