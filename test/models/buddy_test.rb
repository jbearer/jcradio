require 'test_helper'
require 'minitest/mock'

class BuddyTest < ActiveSupport::TestCase
  def setup
    super
    @station = stations(:one)
    @human = users(:one)
    @other = users(:two)
    @slacks = song('Slacks', 'S', 'K')
    QueueEntry.create!(song: @slacks, station: @station, position: 1, selector: @human)
    @station.update! queue_pos: 1, next_letter: 'S', buddy_taste: []
    @buddy = User.create!(username: Buddy::USERNAME, station: @station, position: 0)
    @human.update! station: @station, position: 1
  end

  test "Buddy queues a song with the letter and hands the turn on quietly to the only human" do
    events = []
    queued = []
    chosen = LiveRPC.stub :broadcast, lambda { |function, args| events << [function, *args] } do
      @station.stub :queue_song, lambda { |song, selector, recommended| queued << [song, selector, recommended]; '' } do
        Buddy.take_turn(@station)
      end
    end

    assert_equal @slacks, chosen
    assert_equal [[@slacks, @buddy, false]], queued
    assert_equal @human, @station.current_selector
    assert_equal 'K', @station.reload.next_letter
    assert_equal [[:next_up, @human, 'K', false]], events
  end

  test "Buddy notifies the next human when more than one is listening" do
    @other.update! station: @station, position: 2

    events = []
    LiveRPC.stub :broadcast, lambda { |function, args| events << [function, *args] } do
      @station.stub :queue_song, '' do
        Buddy.take_turn(@station)
      end
    end

    assert_equal [[:next_up, @human, 'K', true]], events
  end

  test "Buddy does nothing when it is not his turn" do
    @buddy.update! position: 5
    assert_nil take_turn_without_queueing
  end

  test "Buddy waits when alone with enough songs already queued" do
    @human.update! station: nil, position: nil
    QueueEntry.create!(song: @slacks, station: @station, position: 2)
    @station.update! buddy_max_songs: 1
    assert_nil take_turn_without_queueing

    @station.update! buddy_max_songs: 2
    assert_equal @slacks, take_turn_quietly
  end

  test "Buddy waits when the queue is long" do
    (2..(Buddy::LONG_QUEUE + 2)).each do |position|
      QueueEntry.create!(song: @slacks, station: @station, position: position)
    end
    assert_nil take_turn_without_queueing
  end

  test "Buddy keeps his place when Spotify refuses the song" do
    LiveRPC.stub :broadcast, lambda { |*| flunk 'a failed selection must not advance the turn' } do
      @station.stub :queue_song, 'Please log into spotify' do
        assert_nil Buddy.take_turn(@station)
      end
    end
    assert_equal @buddy, @station.current_selector
  end

  test "Buddy draws from a listener's played songs and ignores tastes he cannot use" do
    sound = song('Sound', 'S', 'D')
    QueueEntry.create!(song: sound, station: @station, position: 0, selector: @other)
    @station.update! buddy_taste: ["#{@other.username}_played", 'Nobody_played', 'Radio_bogus', 'Radio_spotify']

    assert_equal sound, take_turn_quietly
  end

  test "Buddy draws from upvoted songs, for one listener or for everyone" do
    sound = song('Sound', 'S', 'D')
    entry = QueueEntry.create!(song: sound, station: @station, position: 0, selector: @human)
    Upvote.create!(queue_entry: entry, upvoter: @other)

    @station.update! buddy_taste: ["#{@other.username}_upvoted"]
    assert_equal sound, take_turn_quietly

    @buddy.reload.update! position: 0
    @station.update! buddy_taste: ['Radio_upvoted'], next_letter: 'S'
    assert_equal sound, take_turn_quietly
  end

  test "Buddy draws from a linked Spotify library without saving the whole library" do
    track_type = Struct.new(:id, :name, :uri, :duration_ms, :artists, :album, :preview_url)
    named = Struct.new(:name)
    tracks = ['Sound', 'Mountain'].map do |title|
      track_type.new(title.downcase, title, "spotify:track:#{title}", 1000,
                     [named.new('Artist')], named.new('Album'), nil)
    end
    listener = Struct.new(:username).new(@other.username)
    SpotifyAccounts.link(listener, Object.new)
    @station.update! buddy_taste: ["#{@other.username}_spotify"]

    begin
      chosen = nil
      SpotifyAccounts.stub :library, tracks do
        assert_difference 'Song.count', 1 do
          chosen = take_turn_quietly
        end
      end
      assert_equal 'Sound', chosen.title
      assert chosen.persisted?
    ensure
      SpotifyAccounts.unlink(listener)
    end
  end

  test "a caller that finds Buddy already choosing skips" do
    lock = Buddy.instance_variable_get(:@lock)
    lock.lock
    begin
      assert_nil take_turn_without_queueing
    ensure
      lock.unlock
    end
  end

  test "taste sources are the radio plus everyone who has selected a song" do
    assert_equal [Buddy::RADIO, @human.username], Buddy.taste_sources
  end

  private

  def song(title, first_letter, next_letter)
    Song.create!(title: title, first_letter: first_letter, next_letter: next_letter,
                 source: 'Spotify', source_id: title.downcase, duration: 1000)
  end

  def take_turn_quietly
    LiveRPC.stub :broadcast, nil do
      @station.stub :queue_song, '' do
        Buddy.take_turn(@station)
      end
    end
  end

  def take_turn_without_queueing
    @station.stub :queue_song, lambda { |*| flunk 'Buddy must not queue a song here' } do
      Buddy.take_turn(@station)
    end
  end
end
