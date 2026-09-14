require 'test_helper'
require 'minitest/mock'

class SongsHelperTest < ActiveSupport::TestCase
  # The examples table in docs/letter-rules.md.
  test "letter rules match the documented examples" do
    examples = {
      'The Sound of Silence (Live) - Remastered' => %w[S S],
      'Move Like You Want - Live' => %w[M W],
      'Radio' => %w[R A],
      'Love' => %w[L L],
      'ABC' => %w[A C],
      'AB' => %w[A A],
      'X' => %w[X X],
    }
    examples.each do |title, (first, following)|
      assert_equal first, SongsHelper.first_letter(title), title
      assert_equal following, SongsHelper.calculate_next_letter(title), title
    end

    assert_equal '_', SongsHelper.first_letter('123')
    assert_match(/\A[A-Z]\z/, SongsHelper.calculate_next_letter('123'))
  end

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
