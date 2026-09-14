# Process-level radio state lives in lib/ so it is loaded once and survives
# development-mode code reloads; see lib/spotify_accounts.rb and lib/playback_poller.rb.
require "live-rpc"
require "spotify_accounts"
require "playback_poller"

Rails.application.config.after_initialize do
    unless Rails.env.test?
        radio = SpotifyAccounts.restore_radio
        Rails.logger.info(radio ? "Radio Spotify account restored: #{radio.display_name}" : "No radio Spotify account saved")
        # Only the web server should follow the player; rake tasks and the console should not.
        PlaybackPoller.start if defined?(Rails::Server)
    end
end
