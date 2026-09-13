# In-process micro-benchmarks of the hot paths, run inside the booted app:
#   ssh jcradio-pi 'bash -lic "cd ~/jcradio && time bin/rails runner script/perf/bench-inprocess.rb"'
# Read-only: no writes, no Spotify calls. Reports ms per call after one warm-up.

require "benchmark"

def bench(label, n = 5)
  yield # warm-up (dev mode compiles templates / resolves assets on first call)
  t = Benchmark.realtime { n.times { yield } }
  puts "%-58s %8.1f ms" % [label, t * 1000 / n]
end

station = Station.find(1)
controller = ApplicationController.new
controller.send(:request=, ActionDispatch::TestRequest.new)
controller.send(:response=, ActionDispatch::TestResponse.new)
view = controller.view_context

puts "--- asset helpers (config.assets.debug=#{Rails.application.config.assets.debug})"
bench("javascript_include_tag 'application'") { view.javascript_include_tag "application", "data-turbolinks-track" => true }
bench("stylesheet_link_tag 'application'") { view.stylesheet_link_tag "application", media: "all" }

puts "--- ActiveRecord queries used by every page"
bench("Station.find 1") { Station.find(1) }
bench("station.queue_max") { station.queue_max }
bench("station.queue_before(15).to_a") { station.queue_before(15).to_a }
bench("queue_before(15) + song + selector (N+1 as in view)") do
  station.queue_before(15).each { |q| q.song.title; q.selector && q.selector.username }
end
bench("  same with .includes(:song, :selector)") do
  station.queue_before(15).includes(:song, :selector).each { |q| q.song.title; q.selector && q.selector.username }
end
bench("station.users.order(:position)[0]") { station.users.order(:position)[0] }
bench("User.where.not(position: nil).order(:position).to_a") { User.where.not(position: nil).order(:position).to_a }
bench("now_playing.song") { Station.find(1).now_playing.song.title }
bench("User#pending_notifications.length (first user)") { User.first.pending_notifications.length }

puts "--- browse queries"
letter = "S"
bench("all_songs browse join (limit 500)", 2) do
  QueueEntry.all.joins(:song).where.not(position: nil).where(songs: { first_letter: letter })
            .limit(500).order("queue_entries.id DESC").map { |q| q.song }.uniq
end
bench("  same with .includes(:song)") do
  QueueEntry.all.joins(:song).includes(:song).where.not(position: nil).where(songs: { first_letter: letter })
            .limit(500).order("queue_entries.id DESC").map { |q| q.song }.uniq
end
bench("  Song-first GROUP BY query (current songs#browse)") do
  Song.joins(:queue_entries).where.not(queue_entries: { position: nil }).where(first_letter: letter)
      .group("songs.id").order("MAX(queue_entries.id) DESC").limit(500).to_a
end
ids = Song.order(:id).limit(500).pluck(:source_id)
bench("Song.where(source_id: 500 ids).to_a") { Song.where(source_id: ids).to_a }
bench("Song.where(source_id: 500 ids).pluck(:id) (SQL only)") { Song.where(source_id: ids).pluck(:id) }
bench("Song.where(source_id: 20 ids).to_a") { Song.where(source_id: ids.first(20)).to_a }
bench("Song.find_by(source:, source_id:)") { Song.find_by(source: "Spotify", source_id: ids.last) }

puts "--- view rendering (in-process, no HTTP)"
songs = Song.order(:id).limit(120).to_a
bench("render songs/_search_results (120 songs, anon)", 3) do
  view.render partial: "songs/search_results", locals: { songs: songs, recommended: false }
end
bench("render songs/_search_results (10 songs, anon)") do
  view.render partial: "songs/search_results", locals: { songs: songs.first(10), recommended: false }
end
bench("Song#to_json x120") { songs.each(&:to_json) }

puts "--- misc"
bench("ActionDispatch reloader file check (app files updated?)") do
  ActionDispatch::Reloader rescue nil
  Rails.application.reloaders.any?(&:updated?)
end
bench("Song.new + fuzzily trigram calc (no save)") do
  s = Song.new(title: "Mountain Sound", artist: "Of Monsters and Men", album: "My Head Is an Animal")
  s.instance_eval { [:title, :artist, :album].each { |f| Fuzzily::String.new(send(f)).trigrams } } rescue nil
end
