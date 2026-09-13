require 'test_helper'
require 'minitest/mock'
require 'uri'

class SongTest < ActiveSupport::TestCase
  test "spotify search requests ten tracks and converts the results" do
    songs = [Object.new]
    request = lambda do |path|
      uri = URI.parse(path)
      query = URI.decode_www_form(uri.query).to_h

      assert_equal 'search', uri.path
      assert_equal 'zombie', query['q']
      assert_equal 'track', query['type']
      assert_equal '10', query['limit']

      { 'tracks' => { 'items' => [{ 'id' => 'spotify-track' }], 'total' => 1 } }
    end
    convert = lambda do |tracks|
      assert_equal 1, tracks.length
      assert_kind_of RSpotify::Track, tracks.first
      assert_equal 'spotify-track', tracks.first.id
      songs
    end

    RSpotify.stub :get, request do
      SongsHelper.stub :get_or_create_from_spotify_record, convert do
        assert_same songs, Song.spotify_search('zombie')
      end
    end
  end

  test "spotify search converts an empty result" do
    response = { 'tracks' => { 'items' => [], 'total' => 0 } }
    convert = lambda do |tracks|
      assert_empty tracks
      []
    end

    RSpotify.stub :get, response do
      SongsHelper.stub :get_or_create_from_spotify_record, convert do
        assert_empty Song.spotify_search('no matching song')
      end
    end
  end
end
