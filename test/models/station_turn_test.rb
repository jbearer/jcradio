require 'test_helper'
require 'minitest/mock'

# Turn order, the handed-off letter, and queue bookkeeping. Spotify never enters here;
# station_test.rb covers the Spotify side of queue_song.
class StationTurnTest < ActiveSupport::TestCase
  def setup
    super
    @station = stations(:one)
    @a, @b = users(:one), users(:two)
    @c = User.create!(username: 'Third')
  end

  test "a newcomer joins right behind the current selector" do
    quietly { @station.join(@a) }
    assert_equal 0, @a.reload.position
    assert_equal @station, @a.station

    quietly { @station.join(@b) }
    quietly { @station.join(@c) }
    assert_equal [@a, @c, @b], @station.members.to_a
    assert_equal [0, 1, 2], @station.members.map(&:position)
  end

  test "joining announces the newcomer" do
    events = record_broadcasts { @station.join(@a) }
    assert_equal [[:push, "#{@a.username} joined the radio."]], events
  end

  test "leaving closes the gap in line" do
    quietly { [@a, @b, @c].each { |user| @station.join(user) } }

    events = record_broadcasts { @station.leave(@c) }
    assert_equal [[:push, "#{@c.username} left the radio."]], events
    assert_equal [@a, @b], @station.members.to_a
    assert_equal [0, 1], @station.members.map(&:position)
    assert_nil @c.reload.station
    assert_nil @c.position

    quietly { @station.leave(@a) }
    assert_equal [@b], @station.members.to_a
    assert_equal 0, @b.reload.position
  end

  test "leaving without a place in line still detaches the listener" do
    @a.update! station: @station, position: nil
    quietly { @station.leave(@a) }
    assert_nil @a.reload.station
  end

  test "the current selector is the head of the line" do
    quietly { @station.join(@a); @station.join(@b) }
    assert_equal @a, @station.current_selector
    assert @station.turn?(@a)
    assert_not @station.turn?(@b)
    assert_not @station.turn?(nil)
    assert @a.can_add_to_queue
    assert_not @b.can_add_to_queue
  end

  test "advancing the turn sends the selector to the back and stores the letter" do
    quietly { @station.join(@a); @station.join(@b) }

    events = record_broadcasts { @station.advance_turn(@a, 'k') }
    assert_equal [@b, @a], @station.members.to_a
    assert_equal 'K', @station.reload.next_letter
    assert_equal [[:next_up, @b, 'K', true]], events
  end

  test "advancing the turn is quiet when the selector is the only human" do
    @b.update! username: Buddy::USERNAME
    quietly { @station.join(@b); @station.join(@a) }

    events = record_broadcasts { @station.advance_turn(@b, 'k') }
    assert_equal [[:next_up, @a, 'K', false]], events
  end

  test "advancing the turn notifies the next human when others are listening" do
    quietly { @station.join(@a); @station.join(@b); @station.join(@c) }

    events = record_broadcasts { @station.advance_turn(@a, 'k') }
    assert_equal [[:next_up, @c, 'K', true]], events
  end

  test "advancing to Buddy never notifies" do
    @b.update! username: Buddy::USERNAME
    quietly { @station.join(@a); @station.join(@b); @station.join(@c) }
    quietly { @station.leave(@c) }

    events = record_broadcasts { @station.advance_turn(@a, 'k') }
    assert_equal [[:next_up, @b, 'K', false]], events
  end

  test "the next letter falls back to the last queued song's letter" do
    @station.update! next_letter: nil
    assert_equal '_', @station.next_letter

    queue_song('Radio', 'D', 1)
    queue_song('Sound', 'S', 2)
    assert_equal 'S', @station.next_letter

    @station.update! next_letter: '_'
    assert_equal 'S', @station.next_letter

    @station.assign_next_letter('  q')
    assert_equal 'Q', @station.reload.next_letter
    @station.assign_next_letter('')
    @station.assign_next_letter(nil)
    assert_equal 'Q', @station.reload.next_letter
  end

  test "songs_remaining counts entries after the cursor" do
    assert_equal 0, @station.songs_remaining
    (1..3).each { |position| queue_song("Song #{position}", 'A', position) }
    @station.update! queue_pos: 1
    assert_equal 2, @station.songs_remaining
    @station.update! queue_pos: 3
    assert_equal 0, @station.songs_remaining
  end

  test "next_song moves the cursor to the reported song even when the queue drifted" do
    first, second, third = (1..3).map { |position| queue_song("Song #{position}", 'A', position) }
    @station.update! queue_pos: 1

    @station.next_song(third)
    assert_equal 3, @station.reload.queue_pos
    assert_equal third, @station.now_playing.song
    assert_equal 3, @station.now_playing.position

    stranger = Song.create!(title: 'Stranger', source: 'Spotify', source_id: 'stranger')
    assert_difference 'QueueEntry.count', 1 do
      @station.next_song(stranger)
    end
    assert_equal stranger, @station.reload.now_playing.song
    assert_nil @station.now_playing.position
    assert_equal 3, @station.queue_pos
  end

  test "buddy settings default until configured" do
    assert_equal Buddy::DEFAULT_TASTE, @station.buddy_taste
    assert_equal 3, @station.buddy_max_songs

    @station.update! buddy_taste: ['Radio_upvoted', 'MyString_played'], buddy_max_songs: 5
    assert_equal ['Radio_upvoted', 'MyString_played'], @station.reload.buddy_taste
    assert_equal 5, @station.buddy_max_songs
  end

  private

  def queue_song(title, next_letter, position)
    song = Song.create!(title: title, first_letter: title[0].upcase, next_letter: next_letter,
                        source: 'Spotify', source_id: title.downcase.tr(' ', '-'), duration: 1000)
    QueueEntry.create!(song: song, station: @station, position: position)
    song
  end

  def record_broadcasts
    events = []
    LiveRPC.stub :broadcast, lambda { |function, args| events << [function, *args] } do
      yield
    end
    events
  end

  def quietly(&block)
    record_broadcasts(&block)
    nil
  end
end
