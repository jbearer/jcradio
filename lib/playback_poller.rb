# Follows the radio account's Spotify player from one background thread. When the track
# changes it advances the station; it also lets Buddy take his turn and nudges a listener
# whose turn it is when the queue is about to run dry.
#
# Lives in lib/ (not autoloaded) so the thread handles survive development-mode reloads.
class PlaybackPoller
    ERROR_RETRY = 5   # seconds to wait after a failed poll
    MIN_INTERVAL = 1  # never poll Spotify faster than this

    @thread = nil
    @refresh = nil
    @lock = Mutex.new

    class << self
        # Start the polling thread if it is not already running.
        def start
            @lock.synchronize do
                return @thread if @thread && @thread.alive?
                @thread = Thread.new { new.run }
            end
        end

        def running?
            !@thread.nil? && @thread.alive?
        end

        # Ask the poller to check the player now instead of at its next scheduled time.
        def wake
            thread = @thread
            thread.wakeup if thread && thread.status == "sleep"
        end

        # Run station.refresh_playback in the background unless one is already running,
        # so a page load never waits on Spotify. Returns the thread.
        def refresh_later(station)
            @lock.synchronize do
                return @refresh if @refresh && @refresh.alive?
                @refresh = Thread.new do
                    ActiveRecord::Base.connection_pool.with_connection do
                        begin
                            station.refresh_playback
                        rescue => e
                            Rails.logger.error "background refresh failed: #{e.message}"
                        end
                    end
                end
            end
        end
    end

    def initialize
        @last_track_id = nil
        @laggard_notified = false
    end

    def run
        Rails.logger.info "PlaybackPoller started"
        loop do
            delay = ActiveRecord::Base.connection_pool.with_connection { poll }
            delay ? sleep(delay) : sleep # nil: idle until woken
        end
    end

    # One check of the player. Returns seconds until the next check, or nil to sleep
    # until something (a sign-in, a page load) wakes the poller.
    def poll
        radio = SpotifyAccounts.radio
        return nil unless radio

        player = radio.player
        return nil if !player || !player.playing?

        station = Station.default
        track = player.currently_playing
        if track && track.id != @last_track_id
            # currently_playing already returned the full track; Track.find would be a
            # second request on the app token, which is what got rate limited.
            song = SongsHelper.get_or_create_from_spotify_record([track], true).first
            station.next_song(song)
            station.update_timing_stats
            # Only remember the track once the station advanced, so a failed loop retries.
            @last_track_id = track.id
        end

        nudge_laggard(station)
        Buddy.take_turn(station)

        [station.time_till_next_song.to_f / 1000 / 10, MIN_INTERVAL].max
    rescue => e
        Rails.logger.error "playback poll failed: #{e.message}"
        if e.respond_to?(:response) && e.response.respond_to?(:headers)
            Rails.logger.error "Retry-After: #{e.response.headers[:retry_after].inspect}"
        end
        e.backtrace.each { |line| Rails.logger.error line }
        ERROR_RETRY
    end

    private

    # Once per dry spell, tell the next human selector the queue is about to run out.
    def nudge_laggard(station)
        if station.songs_remaining > 0
            @laggard_notified = false
            return
        end
        return if @laggard_notified

        @laggard_notified = true
        next_user = station.current_selector
        return if next_user.nil? || Buddy.is?(next_user)

        LiveRPC.broadcast :push, ["Wake up #{next_user.username}, you have a #{station.next_letter}"]
    end
end
