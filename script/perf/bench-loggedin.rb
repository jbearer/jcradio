# Logged-in view-rendering benchmark, in-process, read-only (no HTTP, no Spotify, no writes).
#   ssh jcradio-pi 'bash -lic "cd ~/jcradio && bin/rails runner script/perf/bench-loggedin.rb"'
# Simulates a session for a real user id (does NOT touch users.position or broadcast anything).

require "benchmark"

def bench(label, n = 3)
  yield
  t = Benchmark.realtime { n.times { yield } }
  puts "%-62s %8.1f ms" % [label, t * 1000 / n]
end

def make_view(user_id)
  controller = ApplicationController.new
  req = ActionDispatch::TestRequest.new
  req.session[:user_id] = user_id
  controller.send(:request=, req)
  controller.send(:response=, ActionDispatch::TestResponse.new)
  controller.view_context
end

user = User.where.not(station_id: nil).order(:position).first || User.first
puts "simulating user id=#{user.id} (position #{user.position.inspect})"
songs = Song.order(:id).limit(120).to_a
queries = 0
ActiveSupport::Notifications.subscribe("sql.active_record") { |*| queries += 1 }

puts "--- as-is helpers (current_user re-queried on every call)"
view = make_view(user.id)
queries = 0
view.render partial: "songs/search_results", locals: { songs: songs, recommended: false }
puts "  SQL queries for one 120-song render: #{queries}"
bench("render _search_results 120 songs, logged in") do
  view.render partial: "songs/search_results", locals: { songs: songs, recommended: false }
end
bench("render _search_results 10 songs, logged in") do
  view.render partial: "songs/search_results", locals: { songs: songs.first(10), recommended: false }
end
bench("current_user (helper) x50") { 50.times { view.current_user } }
bench("current_user.can_add_to_queue x50") { 50.times { view.current_user.can_add_to_queue } }
bench("set_current_user before_action body (to_h/as_json)") { JSON.dump(view.current_user.to_h) }

puts "--- with memoized current_user (monkeypatched on this view only)"
view2 = make_view(user.id)
view2.define_singleton_method(:current_user) { @__cu ||= User.find_by(id: session[:user_id]) }
queries = 0
view2.render partial: "songs/search_results", locals: { songs: songs, recommended: false }
puts "  SQL queries for one 120-song render: #{queries}"
bench("render _search_results 120 songs, memoized current_user") do
  view2.render partial: "songs/search_results", locals: { songs: songs, recommended: false }
end

puts "--- memoized current_user + can_add_to_queue hoisted out of the loop"
view3 = make_view(user.id)
cu = User.find_by(id: user.id)
can_add = cu.can_add_to_queue
view3.define_singleton_method(:current_user) { cu }
cu.define_singleton_method(:can_add_to_queue) { can_add }
queries = 0
view3.render partial: "songs/search_results", locals: { songs: songs, recommended: false }
puts "  SQL queries for one 120-song render: #{queries}"
bench("render _search_results 120 songs, memoized + hoisted") do
  view3.render partial: "songs/search_results", locals: { songs: songs, recommended: false }
end
bench("  ...and to_json replaced by precomputed hash") do
  json = songs.map(&:to_json)
  json.each_with_index { |j, i| "<button onclick=\"confirmSong(#{i},#{j})\">" }
end
