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

  test "the browse page looks the current user up once per request" do
    user = users(:one)
    station = stations(:one)
    user.update station: station, position: 0
    # The layout's previous-letters strip needs a non-empty queue.
    song = Song.create!(title: 'Slacks', first_letter: 'S', source: 'Spotify', source_id: 'slacks')
    QueueEntry.create!(song: song, station: station, position: 1, selector: user)
    station.update queue_pos: 1
    session[:user_id] = user.id
    lookups = 0
    counter = lambda do |*args|
      lookups += 1 if args.last.is_a?(Hash) && args.last.key?(:id)
      User.where(args.last).first
    end

    User.stub :find_by, counter do
      get :index
    end

    assert_response :success
    assert_equal 1, lookups
  end

  test "browsing chosen songs returns distinct songs, most recently queued first" do
    me, other = users(:one), users(:two)
    station = stations(:one)
    slacks = Song.create!(title: 'Slacks', first_letter: 'S', source: 'Spotify', source_id: 'slacks')
    sound = Song.create!(title: 'Sound', first_letter: 'S', source: 'Spotify', source_id: 'sound')
    mess = Song.create!(title: 'Mess', first_letter: 'M', source: 'Spotify', source_id: 'mess')
    QueueEntry.create!(song: slacks, station: station, position: 1, selector: me)
    QueueEntry.create!(song: sound, station: station, position: 2, selector: other)
    QueueEntry.create!(song: mess, station: station, position: 3, selector: me)
    queued_again = QueueEntry.create!(song: slacks, station: station, position: 4, selector: me)
    QueueEntry.create!(song: sound, station: station, position: nil, selector: me) # never played
    Upvote.create!(queue_entry: queued_again, upvoter: other)

    assert_equal ['Slacks', 'Sound'], browse_queue('all_songs', 'S', me).map(&:title)
    assert_equal ['Slacks'], browse_queue('my_chosen_songs', 'S', me).map(&:title)
    assert_equal ['Sound'], browse_queue('my_chosen_songs', 'S', other).map(&:title)
    assert_equal ['Slacks'], browse_queue('my_upvoted_songs', 'S', other).map(&:title)
    assert_equal [], browse_queue('my_upvoted_songs', 'S', me).map(&:title)
  end

  private

  def browse_queue(source, letter, user)
    controller = SongsController.new
    rendered = nil
    format = Object.new
    format.define_singleton_method(:js) { |&block| block.call }
    respond = lambda { |&block| block.call(format) }
    render = lambda { |_template, options| rendered = options[:locals][:songs] }
    controller.stub :params, { source: source, query: letter } do
      controller.stub :current_user, user do
        controller.stub :respond_to, respond do
          controller.stub :render, render do
            controller.browse
          end
        end
      end
    end
    rendered
  end

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
              Song.stub :create, persist do
                controller.browse
              end
            end
          end
        end
      end
    end
    rendered
  end
end
