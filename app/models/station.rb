# The shared radio: its queue, whose turn it is, the letter being handed off, and how
# selections reach the radio Spotify account. There is one station (DEFAULT_ID).
class Station < ActiveRecord::Base
    DEFAULT_ID = 1
    DEVICE_UNAVAILABLE = "Radio Spotify device is unavailable. The Pi player is being restarted; try again in a moment."

    has_and_belongs_to_many :songs
    belongs_to :now_playing, class_name: "QueueEntry"
    has_many :users

    serialize :buddy_taste, JSON

    def self.default
        find(DEFAULT_ID)
    end

    #
    # Queue
    #

    def queue
        if self.queue_pos
            return QueueEntry.where(station: self).where.not(position: nil).where("position >= ?", self.queue_pos).order(:position)
        end
        return []
    end

    def queue_before(before)
        if self.queue_pos
            # Views read song and selector for every row; load them in two queries, not 2N.
            return QueueEntry.where(station: self).where.not(position: nil).where("position >= ?", self.queue_pos-before).order(:position).includes(:song, :selector)
        end
        return []
    end


    def queue_max
        return QueueEntry.where(station: self).where.not(position: nil).maximum(:position)
    end

    # Songs queued after the one playing now.
    def songs_remaining
        (queue_max || 0) - (queue_pos || 0)
    end

    #
    # Turn order
    #

    # Listeners in line, current selector first.
    def members
        users.where.not(position: nil).order(:position)
    end

    def humans
        members.where.not(username: Buddy::USERNAME)
    end

    def current_selector
        members.first
    end

    def turn?(user)
        user && user == current_selector
    end

    # A newcomer goes right behind the current selector; everyone after them shifts back.
    def join(user)
        head = users.minimum(:position) || -1
        users.where("position > ?", head).each do |member|
            member.update position: member.position + 1
        end
        user.update station: self, position: head + 1
        LiveRPC.broadcast :push, ["#{user.username} joined the radio."]
    end

    def leave(user)
        if user.position
            users.where("position > ?", user.position).each do |member|
                member.update position: member.position - 1
            end
        end
        user.update station: nil, position: nil
        LiveRPC.broadcast :push, ["#{user.username} left the radio."]
    end

    # After a selection: the selector goes to the back of the line, hands off a letter,
    # and everyone's browser learns who is next.
    def advance_turn(selector, letter)
        selector.update position: (users.maximum(:position) || -1) + 1
        assign_next_letter(letter)
        announce_turn(selector)
    end

    def announce_turn(selector)
        next_user = current_selector
        return unless next_user

        notify_turn = next_user != selector && !Buddy.is?(next_user) && humans.count > 1
        LiveRPC.broadcast :next_up, [next_user, next_letter, notify_turn]
    end

    #
    # Letters
    #

    # The letter the next selector must start with. Falls back to the letter handed off
    # by the last queued song when none has been stored (e.g. before the column existed).
    def next_letter
        stored = self[:next_letter]
        return stored if stored.present? && stored != "_"

        last = QueueEntry.where(station: self).where.not(position: nil).order(:position).last
        (last && last.song && last.song.next_letter) || "_"
    end

    # Accepts the selector's override; only the first character counts.
    def assign_next_letter(letter)
        first = letter.to_s.strip[0]
        update next_letter: first.upcase if first
    end

    def buddy_taste
        super || Buddy::DEFAULT_TASTE
    end

    #
    # Playback
    #

    def queue_song(song, selector, was_recommended)
        if song.source != "Spotify"
            return "Please select a song from Spotify (not #{song.source})"
        end

        radio = SpotifyAccounts.radio
        if not radio
            return "Please log into spotify"
        end

        player = radio.player

        # TODO: Automatically create the spotify player. I don't think this
        # can be done with the spotify API
        if not player
            return "No spotify player found.  Please start playing spotify on a device."
        end

        if player.playing?
            # If we are currently playing a song, add this to the queue
            internal_spotify_add_to_queue song.uri
        else
            not_playing = true
            # Otherwise, play this song immediately on spotify
            if radio.display_name == SpotifyAccounts::RADIO_DISPLAY_NAME then
                # If we're using the JC Radio account, play on the pi
                begin
                    start_radio_playback(player, song)
                rescue RestClient::NotFound
                    # The Pi player has lost its Connect registration; restart it and retry once.
                    return DEVICE_UNAVAILABLE unless PlayerWatchdog.recover("transfer to the radio device returned 404")
                    begin
                        start_radio_playback(player, song)
                    rescue RestClient::NotFound
                        return DEVICE_UNAVAILABLE
                    end
                end
            else
                return "Spotify not Playing, and IDK what device to use"
            end
        end

        # Mark the song as queued
        QueueEntry.create song: song, station: self,
            position: (self.queue_max || 0) + 1,
            selector: selector,
            was_recommended: was_recommended

        song.update! last_played: (Time.now.to_f * 1000).to_i

        if not_playing
             # We're not currently playing a song, so immediately skip to this
             # one
            next_song(song)
            update_timing_stats()
        end

        return ""
    end

    # Spotify reports `song` is playing. Normally it is the next entry in the queue, but the
    # queue can drift (songs added outside JC Radio, a missed change), so search forward from
    # the cursor and skip anything in between. A song not in the queue at all gets an
    # unpositioned entry so now_playing is still accurate.
    def next_song(song)
        entry = queue.detect { |queued| queued.song_id == song.id }
        if entry
            update queue_pos: entry.position
        else
            entry = QueueEntry.create song: song
        end

        update now_playing: entry
        logger.info "Now playing: #{song.title} (queue position #{entry.position.inspect})"

        users.each do |user|
            user.notify :next_song_js, entry
            user.notify :update_timing, 0, 0, entry
        end
    end

    # Re-anchor now_playing_start_ms to Spotify's progress and resend it to the browsers.
    def update_timing_stats()
        progress_ms = SpotifyAccounts.radio_progress_ms
        update now_playing_start_ms: Time.now.to_f * 1000 - progress_ms
        return unless now_playing

        users.each do |user|
            user.notify :update_timing, now_playing.song.duration, now_playing_start_ms
        end
    end

    def time_till_next_song()
        end_time = now_playing_start_ms + now_playing.song.duration
        time_diff = end_time - Time.now.to_f * 1000
    end

    # Page loads call this: nudge the poller, let Buddy act, and resend timing.
    def refresh_playback
        PlaybackPoller.wake
        Buddy.take_turn(self)
        update_timing_stats
    end

    # Move the radio account's playback to the Pi and start `song` there.
    def start_radio_playback(player, song)
        SpotifyAccounts.transfer_radio_playback(SpotifyAccounts.radio_device_id)
        player.play_track(nil, song.uri)
    end

    def internal_spotify_add_to_queue(uri)
        # Bypasses RSpotify::User.oauth_post because the queue endpoint returns a non-JSON body.
        # oauth_header/refresh_token are private to the pinned RSpotify 2.9.2; re-check on upgrade.
        spotify_user = SpotifyAccounts.radio
        url = RSpotify::API_URI + "me/player/queue"
        url += "?uri=#{uri}"
        headers = RSpotify::User.send(:oauth_header, spotify_user.id)
        begin
            RestClient.post(url, {}, headers)
        rescue RestClient::Unauthorized
            RSpotify::User.send(:refresh_token, spotify_user.id)
            headers = RSpotify::User.send(:oauth_header, spotify_user.id)
            RestClient.post(url, {}, headers)
        rescue RestClient::ServerBrokeConnection, Errno::ECONNRESET, Errno::EPIPE
            # Pooled connection died underneath us (rest_client_keep_alive.rb); Net::HTTP
            # only retries idempotent verbs itself and Spotify never saw this POST.
            RestClient.post(url, {}, headers)
        end
    end
end
