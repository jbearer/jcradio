# Buddy is the house listener: a User row named "Buddy" who stands in line like everyone
# else. On his turn he picks a song starting with the current letter from what the radio
# or a chosen listener has played, upvoted, or saved on Spotify (the station's buddy_taste).
class Buddy
    USERNAME = "Buddy"
    RADIO = "Radio"              # taste source meaning "everyone", not one listener
    DEFAULT_TASTE = ["Radio_played"]
    LONG_QUEUE = 10              # Buddy waits while this many songs are already queued
    FALLBACK_CANDIDATES = 100    # any songs with the letter when the taste yields none

    @lock = Mutex.new

    class << self
        def user
            User.find_by(username: USERNAME)
        end

        def is?(user)
            !user.nil? && user.username == USERNAME
        end

        def member?(station)
            station.members.where(username: USERNAME).exists?
        end

        def join(station)
            buddy = user
            station.join(buddy) if buddy && !member?(station)
        end

        def leave(station)
            buddy = user
            station.leave(buddy) if buddy && member?(station)
        end

        # Queue one song if it is Buddy's turn. Page loads and the poller both call this,
        # so a caller that finds Buddy already choosing skips rather than waits.
        # Returns the queued song, or nil when Buddy did nothing.
        def take_turn(station)
            return nil unless @lock.try_lock
            begin
                new(station).take_turn
            ensure
                @lock.unlock
            end
        end

        # Names Buddy's taste can refer to: the radio as a whole plus every listener who
        # has selected a song.
        def taste_sources
            selectors = User.where(id: QueueEntry.select(:selector_id)).where.not(username: USERNAME)
            [RADIO] + selectors.order(:username).pluck(:username)
        end
    end

    def initialize(station)
        @station = station
        @letter = station.next_letter
    end

    def take_turn
        buddy = self.class.user
        return nil unless buddy && @station.turn?(buddy)
        return nil if waiting?

        song = choose
        if song.nil?
            Rails.logger.info "Buddy found no songs starting with #{@letter}"
            return nil
        end
        song.save! if song.new_record?

        error = @station.queue_song(song, buddy, false)
        unless error.empty?
            Rails.logger.warn "Buddy could not queue #{song.title}: #{error}"
            return nil
        end

        Rails.logger.info "Buddy chose #{song.title}"
        @station.advance_turn(buddy, song.next_letter)
        song
    end

    private

    def waiting?
        remaining = @station.songs_remaining
        alone = @station.members.count == 1
        (alone && remaining >= @station.buddy_max_songs) || remaining > LONG_QUEUE
    end

    def choose
        candidates = @station.buddy_taste.flat_map { |taste| songs_for(taste) }.uniq
        if candidates.empty?
            candidates = Song.where(first_letter: @letter).limit(FALLBACK_CANDIDATES).to_a
        end
        candidates.sample
    end

    # A taste is "<Radio or username>_<played|upvoted|spotify>".
    def songs_for(taste)
        name, source = taste.to_s.split("_", 2)
        listener = nil
        if name != RADIO
            listener = User.find_by(username: name)
            return [] if listener.nil?
        end

        case source
        when "played"  then played_songs(listener)
        when "upvoted" then upvoted_songs(listener)
        when "spotify" then library_songs(listener)
        else
            Rails.logger.warn "Buddy ignores unknown taste #{taste.inspect}"
            []
        end
    end

    def played_songs(listener)
        entries = QueueEntry.joins(:song).where.not(position: nil).where(songs: { first_letter: @letter })
        entries = entries.where(selector: listener) if listener
        Song.where(id: entries.select(:song_id)).to_a
    end

    def upvoted_songs(listener)
        entries = QueueEntry.joins(:upvotes, :song).where.not(position: nil).where(songs: { first_letter: @letter })
        if listener
            entries = entries.where(upvotes: { upvoter_id: listener.id })
        else
            entries = entries.where.not(upvotes: { upvoter_id: nil })
        end
        Song.where(id: entries.select(:song_id)).to_a
    end

    # Only a listener's library is supported; "Radio_spotify" has nothing to draw from.
    # Songs are not persisted here: a whole library is hundreds of rows, and only the
    # chosen one needs saving.
    def library_songs(listener)
        return [] if listener.nil? || !SpotifyAccounts.linked?(listener)
        tracks = SpotifyAccounts.library(listener)
        SongsHelper.get_or_create_from_spotify_record(tracks).select { |song| song.first_letter == @letter }
    end
end
