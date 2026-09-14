require 'test_helper'
require 'minitest/mock'
require 'tmpdir'

class SpotifyAccountsTest < ActiveSupport::TestCase
  def setup
    super
    @previous_radio = SpotifyAccounts.radio
    @previous_credentials = if RSpotify::User.class_variable_defined?(:@@users_credentials)
      RSpotify::User.class_variable_get(:@@users_credentials).dup
    end
    @listener = Struct.new(:username).new('spotify-accounts-test')
  end

  def teardown
    SpotifyAccounts.unlink(@listener)
    SpotifyAccounts.radio = @previous_radio
    if @previous_credentials
      RSpotify::User.class_variable_set(:@@users_credentials, @previous_credentials)
    end
    super
  end

  test "linking a listener keeps their account and caches their library" do
    account = Object.new
    fetches = 0
    account.define_singleton_method(:saved_tracks) do |limit:, offset:|
      fetches += 1
      offset < 60 ? [:"track-#{offset}"] : []
    end

    assert_not SpotifyAccounts.linked?(@listener)
    assert_equal [], SpotifyAccounts.library(@listener)

    SpotifyAccounts.link(@listener, account)
    assert SpotifyAccounts.linked?(@listener)
    assert_same account, SpotifyAccounts.linked(@listener)
    assert_includes SpotifyAccounts.linked_usernames, @listener.username

    SpotifyAccounts.stub :library_size, 60 do
      assert_equal [:"track-0", :"track-50"], SpotifyAccounts.library(@listener)
      assert_equal 2, fetches, 'a 60-track library is two pages'
      SpotifyAccounts.library(@listener)
      assert_equal 2, fetches, 'the second read is served from the cache'

      SpotifyAccounts.expire_library(@listener)
      SpotifyAccounts.library(@listener)
      assert_equal 4, fetches
    end

    SpotifyAccounts.unlink(@listener)
    assert_not SpotifyAccounts.linked?(@listener)
    assert_not_includes SpotifyAccounts.linked_usernames, @listener.username
  end

  test "the radio account round-trips through the restore file" do
    Dir.mktmpdir do |dir|
      with_restore_file(File.join(dir, 'radio.yml')) do
        SpotifyAccounts.radio = nil
        assert_nil SpotifyAccounts.restore_radio

        account = RSpotify::User.new(
          'id' => 'test-radio', 'display_name' => 'JC Radio',
          'credentials' => { 'token' => 'test-token', 'refresh_token' => 'test-refresh-token' }
        )
        SpotifyAccounts.sign_in_radio(account)
        assert_same account, SpotifyAccounts.radio
        assert File.exist?(SpotifyAccounts.restore_file)

        SpotifyAccounts.radio = nil
        restored = SpotifyAccounts.restore_radio
        assert_equal 'test-radio', restored.id
        assert_equal 'JC Radio', restored.display_name
        assert_same restored, SpotifyAccounts.radio

        SpotifyAccounts.sign_out_radio
        assert_nil SpotifyAccounts.radio
        assert_not File.exist?(SpotifyAccounts.restore_file)
      end
    end
  end

  test "radio progress is unknown without a radio account or while paused" do
    SpotifyAccounts.radio = nil
    assert_equal SpotifyAccounts::NOT_PLAYING_MS, SpotifyAccounts.radio_progress_ms

    SpotifyAccounts.radio = Struct.new(:id).new('radio')
    RSpotify::User.stub :oauth_get, { 'is_playing' => false, 'progress_ms' => 5 } do
      assert_equal SpotifyAccounts::NOT_PLAYING_MS, SpotifyAccounts.radio_progress_ms
    end
    RSpotify::User.stub :oauth_get, { 'is_playing' => true, 'progress_ms' => 5 } do
      assert_equal 5, SpotifyAccounts.radio_progress_ms
    end
  end

  private

  def with_restore_file(path)
    previous = ENV['JCRADIO_SPOTIFY_RESTORE_FILE']
    ENV['JCRADIO_SPOTIFY_RESTORE_FILE'] = path
    yield
  ensure
    if previous
      ENV['JCRADIO_SPOTIFY_RESTORE_FILE'] = previous
    else
      ENV.delete('JCRADIO_SPOTIFY_RESTORE_FILE')
    end
  end
end
