# Restarts the Pi's librespot service when Spotify stops listing it as a device.
#
# librespot can survive a dropped Spotify connection with its TCP session re-established
# but its Connect registration gone, so the process looks healthy while every transfer
# returns 404. The poller calls `check` while the radio is idle; Station calls `recover`
# when a transfer fails so the listener's add can be retried right away.
#
# Lives in lib/ (not autoloaded) so the restart timestamps survive development reloads.
require "shellwords"

module PlayerWatchdog
    CHECK_INTERVAL = 60   # seconds between device-list checks while idle
    COOLDOWN = 300        # seconds between restarts, so a broken player cannot flap
    REGISTER_TIMEOUT = 20 # seconds to wait for a restarted player to appear in Spotify
    DEFAULT_RESTART_COMMAND = "sudo -n systemctl restart jcradio-player"

    @last_check_at = nil
    @last_restart_at = nil
    @lock = Mutex.new

    class << self
        attr_accessor :last_check_at, :last_restart_at

        def restart_command
            ENV.fetch("JCRADIO_PLAYER_RESTART") { DEFAULT_RESTART_COMMAND }.shellsplit
        end

        # Called from the poller loop. Looks at the device list at most once per
        # CHECK_INTERVAL and restarts the player if the radio device is missing.
        # Returns true when a restart was started.
        def check
            now = Time.now
            return false if last_check_at && now < last_check_at + CHECK_INTERVAL
            self.last_check_at = now
            return false if SpotifyAccounts.radio_device_present?

            restart!("Spotify does not list the radio device")
        end

        # Restart the player and wait for Spotify to list the device again. Returns true
        # once the device is back, false if the restart was skipped or the device did not
        # reappear in time.
        def recover(reason)
            return false unless restart!(reason)
            wait_for_device
        end

        # Run the restart command unless one ran within COOLDOWN. Returns true if it ran.
        def restart!(reason)
            @lock.synchronize do
                now = Time.now
                if last_restart_at && now < last_restart_at + COOLDOWN
                    Rails.logger.warn "PlayerWatchdog: #{reason}; last restart #{(now - last_restart_at).round}s ago, not restarting yet"
                    return false
                end
                self.last_restart_at = now
            end

            Rails.logger.warn "PlayerWatchdog: #{reason}; restarting the player"
            run_restart
        end

        def wait_for_device(timeout = REGISTER_TIMEOUT)
            deadline = Time.now + timeout
            loop do
                return true if SpotifyAccounts.radio_device_present?
                return false if Time.now >= deadline
                sleep 1
            end
        end

        private

        def run_restart
            command = restart_command
            return false if command.empty?
            if system(*command)
                true
            else
                Rails.logger.error "PlayerWatchdog: #{command.join(' ')} failed (#{$?.inspect})"
                false
            end
        end
    end
end
