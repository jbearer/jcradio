require 'test_helper'
require 'minitest/mock'

class PlayerWatchdogTest < ActiveSupport::TestCase
  def setup
    super
    @previous_radio = SpotifyAccounts.radio
    @previous_check = PlayerWatchdog.last_check_at
    @previous_restart = PlayerWatchdog.last_restart_at
    PlayerWatchdog.last_check_at = nil
    PlayerWatchdog.last_restart_at = nil
    @restarts = 0
    @restart = lambda { @restarts += 1; true }
  end

  def teardown
    PlayerWatchdog.last_check_at = @previous_check
    PlayerWatchdog.last_restart_at = @previous_restart
    SpotifyAccounts.radio = @previous_radio
    super
  end

  test "the radio device list is read from Spotify" do
    SpotifyAccounts.radio = Struct.new(:id).new('test-radio')
    devices = { 'devices' => [{ 'id' => 'web-player' }, { 'id' => SpotifyAccounts.radio_device_id }] }
    get = lambda do |user_id, path|
      assert_equal 'test-radio', user_id
      assert_equal 'me/player/devices', path
      devices
    end

    RSpotify::User.stub :oauth_get, get do
      assert SpotifyAccounts.radio_device_present?
      devices['devices'].pop
      assert_not SpotifyAccounts.radio_device_present?
    end

    SpotifyAccounts.radio = nil
    assert_equal [], SpotifyAccounts.radio_device_ids
  end

  test "a check restarts the player only when the device is missing" do
    PlayerWatchdog.stub :run_restart, @restart do
      SpotifyAccounts.stub :radio_device_present?, true do
        assert_not PlayerWatchdog.check
      end
      assert_equal 0, @restarts

      PlayerWatchdog.last_check_at = nil
      SpotifyAccounts.stub :radio_device_present?, false do
        assert PlayerWatchdog.check
      end
      assert_equal 1, @restarts
    end
  end

  test "checks are rate limited and never query Spotify more than once per interval" do
    lookups = 0
    lookup = lambda { lookups += 1; true }
    SpotifyAccounts.stub :radio_device_present?, lookup do
      assert_not PlayerWatchdog.check
      assert_not PlayerWatchdog.check
      assert_equal 1, lookups

      PlayerWatchdog.last_check_at = Time.now - PlayerWatchdog::CHECK_INTERVAL - 1
      assert_not PlayerWatchdog.check
      assert_equal 2, lookups
    end
  end

  test "restarts respect the cooldown" do
    PlayerWatchdog.stub :run_restart, @restart do
      assert PlayerWatchdog.restart!('first')
      assert_not PlayerWatchdog.restart!('second'), 'a restart within the cooldown must be skipped'
      assert_equal 1, @restarts

      PlayerWatchdog.last_restart_at = Time.now - PlayerWatchdog::COOLDOWN - 1
      assert PlayerWatchdog.restart!('third')
      assert_equal 2, @restarts
    end
  end

  test "recover restarts and reports whether the device came back" do
    PlayerWatchdog.stub :run_restart, @restart do
      SpotifyAccounts.stub :radio_device_present?, true do
        assert PlayerWatchdog.recover('gone')
      end
      assert_equal 1, @restarts

      # Within the cooldown nothing is restarted and no waiting happens.
      SpotifyAccounts.stub :radio_device_present?, lambda { flunk 'must not poll devices when the restart was skipped' } do
        assert_not PlayerWatchdog.recover('still gone')
      end

      PlayerWatchdog.last_restart_at = nil
      PlayerWatchdog.stub :wait_for_device, false do
        assert_not PlayerWatchdog.recover('gone again')
      end
      assert_equal 2, @restarts
    end
  end

  test "waiting for the device gives up at the deadline" do
    lookups = 0
    lookup = lambda { lookups += 1; lookups >= 3 }
    SpotifyAccounts.stub :radio_device_present?, lookup do
      PlayerWatchdog.stub :sleep, nil do
        assert PlayerWatchdog.wait_for_device(60)
      end
    end
    assert_equal 3, lookups

    SpotifyAccounts.stub :radio_device_present?, false do
      assert_not PlayerWatchdog.wait_for_device(0)
    end
  end

  test "the restart command comes from the environment and is run without a shell" do
    ran = nil
    run = lambda { |*command| ran = command; true }
    begin
      PlayerWatchdog.stub :system, run do
        assert PlayerWatchdog.send(:run_restart)
      end
      assert_equal %w[sudo -n systemctl restart jcradio-player], ran

      ENV['JCRADIO_PLAYER_RESTART'] = "echo 'restart please'"
      PlayerWatchdog.stub :system, run do
        assert PlayerWatchdog.send(:run_restart)
      end
      assert_equal ['echo', 'restart please'], ran

      ENV['JCRADIO_PLAYER_RESTART'] = ''
      assert_not PlayerWatchdog.send(:run_restart), 'an empty command disables restarts'
    ensure
      ENV.delete('JCRADIO_PLAYER_RESTART')
    end
  end
end
