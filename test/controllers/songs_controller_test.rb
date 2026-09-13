require 'test_helper'
require 'minitest/mock'

class SongsControllerTest < ActionController::TestCase
  def setup
    super
    @previous_client_spotifies = $client_spotifies
    $client_spotifies = { 'test-listener' => Object.new }
  end

  def teardown
    $client_spotifies = @previous_client_spotifies
    super
  end

  test "browsing a Spotify library builds results without saving songs" do
    songs = browse_library('')
    assert_equal ['Mountain Sound', 'Slacks'], songs.map(&:title)
    assert songs.all?(&:new_record?)
  end

  test "browsing a Spotify library filters by first letter" do
    songs = browse_library('S')
    assert_equal ['Slacks'], songs.map(&:title)
    assert songs.all?(&:new_record?)
  end

  private

  def browse_library(letter)
    track_type = Struct.new(:id, :name, :uri, :duration_ms, :artists, :album, :preview_url)
    named_type = Struct.new(:name)
    tracks = ['Mountain Sound', 'Slacks'].map do |title|
      track_type.new(
        title, title, "spotify:track:#{title}", 1000,
        [named_type.new('Test artist')], named_type.new('Test album'), nil
      )
    end
    controller = SongsController.new
    user = Struct.new(:username).new('test-listener')
    rendered = nil
    format = Object.new
    format.define_singleton_method(:js) { |&block| block.call }
    respond = lambda { |&block| block.call(format) }
    render = lambda do |template, options|
      assert_equal 'search', template
      rendered = options[:locals][:songs]
    end
    library = lambda do |spotify_user|
      assert_same $client_spotifies['test-listener'], spotify_user
      tracks
    end
    persist = lambda { |*arguments| flunk 'Browsing must not save library songs' }

    controller.stub :params, { source: 'my_spotify_library', query: letter } do
      controller.stub :current_user, user do
        controller.stub :spotify_get_all_songs, library do
          controller.stub :respond_to, respond do
            controller.stub :render, render do
              Song.stub :all, [] do
                Song.stub :create, persist do
                  controller.browse
                end
              end
            end
          end
        end
      end
    end
    rendered
  end
end
