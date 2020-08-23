class Station < ActiveRecord::Base
    has_and_belongs_to_many :songs
    belongs_to :now_playing, class_name: "QueueEntry"
    has_many :users

    def queue
        if self.queue_pos
            return QueueEntry.where(station: self).where.not(position: nil).where("position >= ?", self.queue_pos).order(:position)
        end
    end

    def queue_before(before)
        if self.queue_pos
            return QueueEntry.where(station: self).where.not(position: nil).where("position >= ?", self.queue_pos-before).order(:position)
        end
    end


    def queue_max
        return QueueEntry.where(station: self).where.not(position: nil).maximum(:position)
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
                position: (self.queue_max || 0) + 1,
                selector: selector
        else
            # Play it immediately
            update now_playing: (QueueEntry.create song: song, selector: selector)
        end

        return ""
    end

    def next_song(song)
        # We expect the next song to be the first song on the queue; however, the queue may drift
        # out of sync with what's actually in Spotify (for example, if someone added songs to the
        # queue not using the JCRadio interface, or if we missed a song change). This is a chance
        # to resync the initial part of the queue with Spotify, by dequeuing until we reach the
        # expected song (possibly clearing the queue if the whole thing is invalid).
        #
        # Whatever happens, this method will ensure that `song` is now playing.

        entry = nil
        while queue.any?


            print "$$$$$$$$$$$$$$$$$$$$$$$44444\n"
            print "$$$$$$$$$$$$$$$$$$$$$$$44444\n"
            print "$$$$$$$$$$$$$$$$$$$$$$$44444\n"
            print "  QueueSize: %d\n" % queue.length
            print "  QueuePos: %d\n" % queue_pos
            print "  QueueMax: %d\n" % queue_max
            print "  QueueSong: %s\n" % queue[0].song.name
            print "  SongIn: %s\n" % song.name 

            if queue[0].song == song then
                entry = queue[0]

                print "Found song pos: %d\n" % entry.position
            else
                update queue_pos: queue_pos+1
            end


            # queue[0].update position: nil+
            queue.reload

            break unless entry.nil?
        end

        if entry.nil? then
            entry = QueueEntry.create song: song
        end

        update now_playing: entry

        # Update the clients about the new song.
        users.each do |user|
            user.notify :next_song, entry
        end
    end

    def internal_spotify_add_to_queue(uri)
        url = "me/player/queue"
        url += "?uri=#{uri}"
        RSpotify::User.oauth_post($spotify_user.id, url, {})
    end
end
