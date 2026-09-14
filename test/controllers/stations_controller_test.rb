require 'test_helper'
require 'minitest/mock'

class StationsControllerTest < ActionController::TestCase
  def setup
    super
    @previous_letter = $the_next_letter
    @previous_buddy_taste = $buddy_taste
    @previous_buddy_last_add = $buddy_last_add
  end

  def teardown
    $the_next_letter = @previous_letter
    $buddy_taste = @previous_buddy_taste
    $buddy_last_add = @previous_buddy_last_add
    super
  end

  test "queue snapshots include the queue and next turn without refreshing Spotify or Buddy" do
    station, song = prepare_queue
    listener = users(:one)
    listener.update! station: station, position: 0
    $the_next_letter = 'K'
    @controller.define_singleton_method(:refresh_now_playing_in_background) do
      raise 'Queue snapshots must not trigger Spotify or Buddy'
    end

    get :show, id: station.id, format: :json

    assert_response :success
    state = JSON.parse(response.body)
    assert_includes state['queue_html'], song.title
    assert_equal listener.id, state['next_user']['id']
    assert_equal 'K', state['next_letter']
    assert_no_match(/<html|<script/, state['queue_html'])
  end

  test "Buddy broadcasts a quiet turn update when only one human is listening" do
    event = finish_buddy_turn(false)
    assert_equal :next_up, event[0]
    assert_equal users(:one), event[1]
    assert_equal 'K', event[2]
    assert_equal false, event[3]
  end

  test "Buddy broadcasts a turn notification when other humans are listening" do
    event = finish_buddy_turn(true)
    assert_equal :next_up, event[0]
    assert_equal users(:one), event[1]
    assert_equal 'K', event[2]
    assert_equal true, event[3]
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

  private

  def prepare_queue
    station = stations(:one)
    song = Song.create!(title: 'Slacks', first_letter: 'S', next_letter: 'K',
                        source: 'Spotify', source_id: 'slacks', duration: 1000)
    QueueEntry.create!(song: song, station: station, position: 1)
    station.update! queue_pos: 1
    [station, song]
  end

  def finish_buddy_turn(other_listener)
    station, song = prepare_queue
    users(:one).update! station: station, position: 1
    users(:two).update! station: station, position: 2 if other_listener
    User.create!(username: 'Buddy', station: station, position: 0)
    $the_next_letter = 'S'
    $buddy_taste = []
    $buddy_last_add = 0
    @controller.instance_variable_set(:@station, station)
    events = []
    @controller.stub :broadcast, lambda { |*args| events << args } do
      station.stub :queue_song, '' do
        @controller.buddy_add_song
      end
    end
    assert_equal 1, events.length
    events.first
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
      @controller.stub :broadcast, lambda { |*args| events << args } do
        station.stub :queue_song, '' do
          post :update, id: station.id, source_id: song.source_id,
                        song_next_letter: 'k', was_recommended: false, format: :json
        end
      end
    end

    assert_response :success
    assert_equal true, JSON.parse(response.body)['success']
    assert_equal next_user, station.users.order(:position).first
    assert_equal 1, events.length
    events.first
  end
end
