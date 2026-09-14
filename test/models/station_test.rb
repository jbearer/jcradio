require 'test_helper'
require 'minitest/mock'

class StationTest < ActiveSupport::TestCase
  def setup
    super
    @previous_spotify_user = $spotify_user
    @previous_credentials = if RSpotify::User.class_variable_defined?(:@@users_credentials)
      RSpotify::User.class_variable_get(:@@users_credentials).dup
    end
  end

  def teardown
    $spotify_user = @previous_spotify_user
    if @previous_credentials
      RSpotify::User.class_variable_set(:@@users_credentials, @previous_credentials)
    elsif RSpotify::User.class_variable_defined?(:@@users_credentials)
      RSpotify::User.send(:remove_class_variable, :@@users_credentials)
    end
    super
  end

  test "a successful non JSON queue response creates one local entry" do
    assert_successful_queue_response('spotify-request-id')
  end

  test "an empty successful queue response creates one local entry" do
    assert_successful_queue_response('')
  end

  test "successful queue additions record last played for Buddy and human selectors" do
    station = stations(:one)
    buddy = users(:two)
    buddy.update! username: 'Buddy'
    chosen_at = Time.utc(2026, 9, 13, 23, 21)

    [buddy, users(:one)].each do |selector|
      song = set_playing_radio
      Time.stub :now, chosen_at do
        station.stub :internal_spotify_add_to_queue, nil do
          assert_difference 'QueueEntry.count', 1 do
            assert_equal '', station.queue_song(song, selector, false)
          end
        end
      end

      assert_equal (chosen_at.to_f * 1000).to_i, song.reload.last_played
      assert_equal selector, song.queue_entries.last.selector
      assert_equal song.last_played, song.as_json['last_played']
    end
  end

  test "rejected queue additions leave last played unchanged" do
    station = stations(:one)
    song = set_playing_radio
    previous_play = 1_600_000_000_000
    song.update! last_played: previous_play

    station.stub :internal_spotify_add_to_queue, lambda { |uri| raise RestClient::Forbidden } do
      assert_no_difference 'QueueEntry.count' do
        assert_raises(RestClient::Forbidden) { station.queue_song(song, users(:one), false) }
      end
    end
    assert_equal previous_play, song.reload.last_played

    $spotify_user = nil
    assert_no_difference 'QueueEntry.count' do
      assert_equal 'Please log into spotify', station.queue_song(song, users(:one), false)
    end
    assert_equal previous_play, song.reload.last_played
  end

  test "an expired queue token is refreshed and retried once" do
    set_radio_credentials
    requests = []
    request = lambda do |url, body, headers|
      requests << url
      if url == RSpotify::TOKEN_URI
        assert_equal 'refresh_token', body[:grant_type]
        assert_equal 'test-refresh-token', body[:refresh_token]
        '{"access_token":"new-test-token"}'
      elsif requests.length == 1
        raise RestClient::Unauthorized.new('Missing/invalid/expired access token')
      else
        assert_equal 'Bearer new-test-token', headers['Authorization']
        'spotify-request-id'
      end
    end

    RSpotify.stub :auth_header, {} do
      RestClient.stub :post, request do
        Station.new.internal_spotify_add_to_queue('spotify:track:test-track')
      end
    end
    assert_equal 3, requests.length
    assert_equal requests.first, requests.last
  end

  test "a queue POST on a connection Spotify already closed is retried once" do
    set_radio_credentials
    requests = 0
    request = lambda do |url, body, headers|
      requests += 1
      raise RestClient::ServerBrokeConnection if requests == 1
      'spotify-request-id'
    end

    RestClient.stub :post, request do
      Station.new.internal_spotify_add_to_queue('spotify:track:test-track')
    end
    assert_equal 2, requests
  end

  test "a malformed refresh response is not mistaken for a queued song" do
    set_radio_credentials
    requests = 0
    request = lambda do |url, body, headers|
      requests += 1
      if url == RSpotify::TOKEN_URI
        'not-json'
      else
        raise RestClient::Unauthorized.new('Missing/invalid/expired access token')
      end
    end

    RSpotify.stub :auth_header, {} do
      RestClient.stub :post, request do
        assert_raises(JSON::ParserError) do
          Station.new.internal_spotify_add_to_queue('spotify:track:test-track')
        end
      end
    end
    assert_equal 2, requests
  end

  test "queue HTTP failures do not retry or create a local entry" do
    [RestClient::Forbidden, RestClient::NotFound,
     RestClient::TooManyRequests, RestClient::InternalServerError].each do |error_class|
      song = set_playing_radio
      requests = 0
      request = lambda do |*arguments|
        requests += 1
        raise error_class.new('request rejected')
      end
      create_entry = lambda { |*arguments| flunk 'Must not create a queue entry when Spotify rejects it' }

      RestClient.stub :post, request do
        QueueEntry.stub :create, create_entry do
          assert_raises(error_class) { Station.new.queue_song(song, nil, false) }
        end
      end
      assert_equal 1, requests
    end
  end

  test "a queue 401 that persists after refresh raises and creates no local entry" do
    song = set_playing_radio
    requests = []
    request = lambda do |url, body, headers|
      requests << url
      if url == RSpotify::TOKEN_URI
        '{"access_token":"new-test-token"}'
      else
        raise RestClient::Unauthorized.new('Missing/invalid/expired access token')
      end
    end
    create_entry = lambda { |*arguments| flunk 'Must not create a queue entry when Spotify rejects it' }

    RSpotify.stub :auth_header, {} do
      RestClient.stub :post, request do
        QueueEntry.stub :create, create_entry do
          assert_raises(RestClient::Unauthorized) { Station.new.queue_song(song, nil, false) }
        end
      end
    end
    assert_equal 3, requests.length
    assert_equal RSpotify::TOKEN_URI, requests[1]
  end

  test "RSpotify oauth requests refresh on the current Spotify 401 wording" do
    set_radio_credentials
    gets = 0
    get = lambda do |url, headers|
      gets += 1
      if gets == 1
        raise RestClient::Unauthorized.new('Missing/invalid/expired access token')
      else
        assert_equal 'Bearer new-test-token', headers['Authorization']
        '{"is_playing":true}'
      end
    end
    post = lambda do |url, body, headers|
      assert_equal RSpotify::TOKEN_URI, url
      '{"access_token":"new-test-token"}'
    end

    RSpotify.stub :auth_header, {} do
      RestClient.stub :get, get do
        RestClient.stub :post, post do
          response = RSpotify::User.oauth_get('test-radio', 'me/player')
          assert_equal true, response['is_playing']
        end
      end
    end
    assert_equal 2, gets
  end

  test "an unavailable radio device does not start playback or create a queue entry" do
    player = Minitest::Mock.new
    player.expect :!, false
    player.expect :playing?, false
    $spotify_user = Struct.new(:player, :display_name).new(player, 'JC Radio')
    song = Struct.new(:source, :uri).new('Spotify', 'spotify:track:test-track')
    transfer = lambda do |device_id|
      assert_equal $JCRADIO_PI, device_id
      raise RestClient::NotFound
    end
    create_entry = lambda { |*arguments| flunk 'Must not create a queue entry when transfer fails' }

    StationsHelper.stub :set_device, transfer do
      QueueEntry.stub :create, create_entry do
        message = Station.new.queue_song(song, nil, false)
        assert_match(/device is unavailable/, message)
        assert_match(/Start librespot/, message)
      end
    end
    player.verify
  end

  test "a radio device disappearing before playback does not create a queue entry" do
    player = Minitest::Mock.new
    player.expect :!, false
    player.expect :playing?, false
    player.expect(:play_track, nil) { |device_id, uri| raise RestClient::NotFound }
    $spotify_user = Struct.new(:player, :display_name).new(player, 'JC Radio')
    song = Struct.new(:source, :uri).new('Spotify', 'spotify:track:test-track')
    create_entry = lambda { |*arguments| flunk 'Must not create a queue entry when playback fails' }

    StationsHelper.stub :set_device, nil do
      QueueEntry.stub :create, create_entry do
        message = Station.new.queue_song(song, nil, false)
        assert_match(/device is unavailable/, message)
      end
    end
  end

  private

  def set_radio_credentials
    $spotify_user = RSpotify::User.new(
      'id' => 'test-radio',
      'credentials' => { 'token' => 'test-token', 'refresh_token' => 'test-refresh-token' }
    )
  end

  def set_playing_radio
    set_radio_credentials
    $spotify_user.define_singleton_method(:player) { Struct.new(:playing?).new(true) }
    Song.create!(source: 'Spotify', source_id: 'test-track', uri: 'spotify:track:test-track',
                 title: 'Test track', artist: 'Test artist', album: 'Test album')
  end

  def assert_successful_queue_response(response)
    song = set_playing_radio
    station = Station.new
    requests = 0
    entries = []
    request = lambda do |url, body, headers|
      requests += 1
      assert_equal RSpotify::API_URI + 'me/player/queue?uri=spotify:track:test-track', url
      assert_equal 'Bearer test-token', headers['Authorization']
      response
    end
    create_entry = lambda { |attributes| entries << attributes }

    RestClient.stub :post, request do
      station.stub :queue_max, 4 do
        QueueEntry.stub :create, create_entry do
          assert_equal '', station.queue_song(song, nil, false)
        end
      end
    end
    assert_equal 1, requests
    assert_equal 1, entries.length
    assert_equal song, entries.first[:song]
    assert_equal 5, entries.first[:position]
  end
end
