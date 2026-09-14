require 'test_helper'
require 'minitest/mock'

class StationsControllerTest < ActionController::TestCase
  test "queue snapshots include the queue and next turn without refreshing Spotify or Buddy" do
    station, song = prepare_queue
    listener = users(:one)
    listener.update! station: station, position: 0
    station.update! next_letter: 'K'
    refresh = lambda { |*| raise 'Queue snapshots must not trigger Spotify or Buddy' }

    PlaybackPoller.stub :refresh_later, refresh do
      get :show, id: station.id, format: :json
    end

    assert_response :success
    state = JSON.parse(response.body)
    assert_includes state['queue_html'], song.title
    assert_equal listener.id, state['next_user']['id']
    assert_equal 'K', state['next_letter']
    assert_no_match(/<html|<script/, state['queue_html'])
  end

  test "a human addition notifies the next human and updates all queue viewers" do
    event = finish_human_turn(false)
    assert_equal :next_up, event[0]
    assert_equal users(:two), event[1]
    assert_equal 'K', event[2]
    assert_equal true, event[3]
  end

  test "a human addition broadcasts Buddy's turn without a notification" do
    event = finish_human_turn(true)
    assert_equal :next_up, event[0]
    assert_equal 'Buddy', event[1].username
    assert_equal 'K', event[2]
    assert_equal false, event[3]
  end

  test "adding a song out of turn is rejected" do
    station, song = prepare_queue
    users(:one).update! station: station, position: 0
    waiting = users(:two)
    waiting.update! station: station, position: 1
    queued = lambda { |*| flunk 'Must not queue a song out of turn' }

    @controller.stub :current_user, waiting do
      station.stub :queue_song, queued do
        post :update, id: station.id, source_id: song.source_id, format: :json
      end
    end

    body = JSON.parse(response.body)
    assert_equal false, body['success']
    assert_match(/not your turn/, body['error'])
    assert_equal 1, waiting.reload.position
  end

  test "showing the station defers the Spotify refresh to the poller" do
    station, _song = prepare_queue
    refreshed = []

    PlaybackPoller.stub :refresh_later, lambda { |target| refreshed << target } do
      get :show, id: station.id
    end

    assert_response :success
    assert_equal [station], refreshed
  end

  private

  def prepare_queue
    station = stations(:one)
    song = Song.create!(title: 'Slacks', first_letter: 'S', next_letter: 'K',
                        source: 'Spotify', source_id: 'slacks', duration: 1000)
    QueueEntry.create!(song: song, station: station, position: 1)
    station.update! queue_pos: 1
    [station, song]
  end

  def finish_human_turn(next_is_buddy)
    station, song = prepare_queue
    selector = users(:one)
    selector.update! station: station, position: 0
    next_user = users(:two)
    next_user.update! station: station, position: 1
    next_user.update! username: 'Buddy' if next_is_buddy
    events = []

    @controller.stub :current_user, selector do
      LiveRPC.stub :broadcast, lambda { |function, args| events << [function, *args] } do
        station.stub :queue_song, '' do
          post :update, id: station.id, source_id: song.source_id,
                        song_next_letter: 'k', was_recommended: false, format: :json
        end
      end
    end

    assert_response :success
    assert_equal true, JSON.parse(response.body)['success']
    assert_equal next_user, station.current_selector
    assert_equal 'K', station.reload.next_letter
    assert_equal 1, events.length
    events.first
  end
end
