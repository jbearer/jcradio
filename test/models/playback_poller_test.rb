require 'test_helper'
require 'minitest/mock'

class PlaybackPollerTest < ActiveSupport::TestCase
  def setup
    super
    @previous_radio = SpotifyAccounts.radio
  end

  def teardown
    SpotifyAccounts.radio = @previous_radio
    super
  end

  test "refresh_later runs the station refresh on another thread, one at a time" do
    ran_on = Queue.new
    gate = Queue.new
    station = Object.new
    station.define_singleton_method(:refresh_playback) { ran_on << Thread.current; gate.pop }

    first = PlaybackPoller.refresh_later(station)
    assert_not_same Thread.current, ran_on.pop
    assert_same first, PlaybackPoller.refresh_later(station), 'a running refresh must not be duplicated'

    gate << :done
    first.join
    assert_not first.alive?
  end

  test "wake is harmless when the poller is not running" do
    assert_nothing_raised { PlaybackPoller.wake }
    assert_not PlaybackPoller.running?
  end

  test "a poll idles until woken when there is no radio account or player" do
    SpotifyAccounts.radio = nil
    assert_nil PlaybackPoller.new.poll

    SpotifyAccounts.radio = Struct.new(:player).new(nil)
    assert_nil PlaybackPoller.new.poll
  end

  test "an idle poll has the watchdog confirm the device and checks again later" do
    SpotifyAccounts.radio = Struct.new(:player).new(Struct.new(:playing?).new(false))
    checks = 0
    PlayerWatchdog.stub :check, lambda { checks += 1; false } do
      assert_equal PlayerWatchdog::CHECK_INTERVAL, PlaybackPoller.new.poll
    end
    assert_equal 1, checks
  end

  test "a poll that sees a new track advances the station and schedules the next check" do
    station = stations(:one)
    song = Song.create!(title: 'Slacks', first_letter: 'S', next_letter: 'K',
                        source: 'Spotify', source_id: 'slacks', duration: 200_000)
    QueueEntry.create!(song: song, station: station, position: 1)
    station.update! queue_pos: 1
    track = RSpotify::Track.new('id' => 'slacks', 'name' => 'Slacks')
    player = Struct.new(:playing?, :currently_playing).new(true, track)
    SpotifyAccounts.radio = Struct.new(:player, :id).new(player, 'radio')
    fetch = lambda { |*arguments| flunk "polling must not call RSpotify.get (#{arguments.first})" }
    poller = PlaybackPoller.new

    delay = SpotifyAccounts.stub :radio_progress_ms, 10_000 do
      RSpotify.stub :get, fetch do
        poller.poll
      end
    end

    assert_equal song, station.reload.now_playing.song
    assert_in_delta 19.0, delay, 1.0, 'ten percent of the remaining 190 s'

    # The same track again is not a change; the station is left alone.
    advance = lambda { |*| flunk 'an unchanged track must not advance the station' }
    Station.stub :default, lambda { station } do
      station.stub :next_song, advance do
        assert_in_delta 19.0, poller.poll, 1.0
      end
    end
  end

  test "a failed poll is logged and retried soon" do
    player = Object.new
    player.define_singleton_method(:playing?) { raise RestClient::TooManyRequests }
    SpotifyAccounts.radio = Struct.new(:player).new(player)

    assert_equal PlaybackPoller::ERROR_RETRY, PlaybackPoller.new.poll
  end
end
