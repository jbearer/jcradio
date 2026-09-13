require 'test_helper'
require 'minitest/mock'

class SongsHelperTest < ActiveSupport::TestCase
  test "converting a track with a null preview_url does not fetch the track again" do
    track = RSpotify::Track.new(
      'id' => 'library-track', 'name' => 'Mountain Sound', 'uri' => 'spotify:track:library-track',
      'duration_ms' => 1000, 'preview_url' => nil,
      'artists' => [{ 'name' => 'Of Monsters and Men' }], 'album' => { 'name' => 'My Head Is an Animal' }
    )
    fetch = lambda { |*arguments| flunk "Conversion must not call RSpotify.get (#{arguments.first})" }

    RSpotify.stub :get, fetch do
      songs = SongsHelper.get_or_create_from_spotify_record([track])
      assert_equal 1, songs.length
      assert_equal 'Mountain Sound', songs.first.title
      assert_nil songs.first.preview_url
      assert songs.first.new_record?
    end
  end

  test "converting a track already in the database returns the stored song" do
    stored = Song.create!(source: 'Spotify', source_id: 'stored-track', title: 'Slacks')
    track = RSpotify::Track.new('id' => 'stored-track', 'name' => 'Slacks')
    fetch = lambda { |*arguments| flunk "Conversion must not call RSpotify.get (#{arguments.first})" }

    RSpotify.stub :get, fetch do
      assert_equal [stored], SongsHelper.get_or_create_from_spotify_record([track])
    end
  end
end
