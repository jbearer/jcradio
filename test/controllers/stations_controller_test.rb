require 'test_helper'

class StationsControllerTest < ActionController::TestCase
  test "showing the station defers the Spotify refresh to a background thread" do
    station = stations(:one)
    song = Song.create!(title: 'Slacks', first_letter: 'S', next_letter: 'K', source: 'Spotify', source_id: 'slacks')
    QueueEntry.create!(song: song, station: station, position: 1)
    station.update queue_pos: 1
    refreshed_on = Queue.new
    @controller.define_singleton_method(:refresh_now_playing_and_stuff) { refreshed_on << Thread.current }

    get :show, id: station.id

    assert_response :success
    assert_not_same Thread.current, refreshed_on.pop
    $refresh_thread.join
  end
end
