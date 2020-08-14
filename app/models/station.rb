class Station < ActiveRecord::Base
    has_and_belongs_to_many :songs
    belongs_to :now_playing, class_name: "QueueEntry"
    has_many :users

    def queue
        QueueEntry.where(station: self).where.not(position: nil).order(:position)
    end

    def queue_song(song, selector)
        if song.source != "Spotify"
            return "Please select a song from Spotify (not #{song.source})"
        end

        if not $spotify_user
            return "Please log into spotify"
        end

        player = $spotify_user.player

        # TODO: Automatically create the spotify player. I don't think this
        # can be done with the spotify API
        if not player
            return "No spotify player found.  Please start playing spotify on a device."
        end

        if player.playing?
            # If we are currently playing a song, add this to the queue
            internal_spotify_add_to_queue song.uri
        else
            # Otherwise, play this song immediately
            # TODO: Causes RestClient::NotFound :( :( :(
            # player.play_track(uri)
            return "Spotify not Playing. (Might be logged in as wrong Spotify)"
        end


        if self.now_playing
            # Queue the song
            QueueEntry.create song: song, station: self,
                position: (queue.maximum(:position) || 0) + 1,
                selector: selector
        else
            # Play it immediately
            update now_playing: (QueueEntry.create song: song, selector: selector)
        end

        return ""
    end

    def dequeue_song(song)
        # Dequeue everything up to and including the given song.
        # Typically, when this method is called, `song` should be the first song on the queue.
        # However, this method also serves as a chance to fix the queue in our database if it has
        # drifted from the Spotify queue (for example, if someone added songs to the queue not using
        # the JCRadio interface, or if we missed a song change).
        while queue
            finished = song == queue[0]
            queue[0].update position: nil
            if finished
                break
            end
        end

        # Dequeue the next song and play it
        if queue
            update now_playing: (queue[0].update position: nil)
        end
    end

    def internal_spotify_add_to_queue(uri)
        url = "me/player/queue"
        url += "?uri=#{uri}"
        RSpotify::User.oauth_post($spotify_user.id, url, {})
    end
end
