class Station < ActiveRecord::Base
    has_and_belongs_to_many :songs
    belongs_to :now_playing, class_name: "QueueEntry"
    has_many :users

    

    include StationsHelper

    def queue
        if self.queue_pos
            return QueueEntry.where(station: self).where.not(position: nil).where("position >= ?", self.queue_pos).order(:position)
        end
        return []
    end

    def queue_before(before)
        if self.queue_pos
            return QueueEntry.where(station: self).where.not(position: nil).where("position >= ?", self.queue_pos-before).order(:position)
        end
        return []
    end


    def queue_max
        return QueueEntry.where(station: self).where.not(position: nil).maximum(:position)
    end

    def queue_song(song, selector, was_recommended)
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
            not_playing = true
            # Otherwise, play this song immediately on spotify
            if $spotify_user.display_name == "JC Radio" then
                # If we're using the JC Radio account, play on the pi
                StationsHelper.set_device($JCRADIO_PI)
                player.play_track(nil, song.uri)
            else
                return "Spotify not Playing, and IDK what device to use"
            end
        end

        # Mark the song as queued
        QueueEntry.create song: song, station: self,
            position: (self.queue_max || 0) + 1,
            selector: selector,
            was_recommended: was_recommended

        if not_playing
             # We're not currently playing a song, so immediately skip to this
             # one
            next_song(song)
            update_timing_stats()
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

        logger.error("**************")
        logger.error("station.rb: next_song() start")
        logger.error("**************")


        entry = nil

        tmp_pos = queue_pos

        while queue.any? and tmp_pos <= queue_max

            # print "$$$$$$$$$$$$$$$$$$$$$$$44444\n"
            # print "$$$$$$$$$$$$$$$$$$$$$$$44444\n"
            # print "$$$$$$$$$$$$$$$$$$$$$$$44444\n"
            # print "  QueueSize: %d\n" % queue.length
            # print "  QueuePos: %d\n" % queue_pos
            # print "  TmpPos: %d\n" % tmp_pos
            # print "  QueueMax: %d\n" % queue_max

            if queue[tmp_pos - queue_pos].song == song then
                entry = queue[tmp_pos - queue_pos]

                # print "Found song pos: %d\n" % entry.position

                update queue_pos: tmp_pos # Update actual queue pos if found the song
                queue.reload
            else
                tmp_pos = tmp_pos + 1
            end


            # queue[0].update position: nil+

            break unless entry.nil?
        end

        if entry.nil? then
            # print "$$$$$$$$$$$$$$$$$$$$$$$44444\n"
            # print "  Song not found. Creating new QueueEntry\n"
            entry = QueueEntry.create song: song
        end

        update now_playing: entry

        logger.error("**************")
        logger.error("station.rb: next_song() entry")
        logger.error(entry.inspect)
        logger.error("**************")

        # Update the clients about the new song.
        users.each do |user|
            user.notify :next_song_js, entry
            logger.error("**************")
            logger.error("station.rb: next_song().notify")
            logger.error("**************")
        end

        # Update the clients about the timing.
        users.each do |user|
            user.notify :update_timing, 0, 0, entry
            logger.error("**************")
            logger.error("station.rb: next_song().notify update_timing")
            logger.error("**************")
        end


        logger.error("**************")
        logger.error("station.rb: next_song() end")
        logger.error("**************")

    end

    # Update now_playing_start_ms
    # Call javascript to update the now_playing progress bar
    def update_timing_stats()
        progress_ms = StationsHelper.get_progress_ms
        update now_playing_start_ms: Time.now.to_f * 1000 - progress_ms

        # Update the clients about the timing.
        users.each do |user|
            user.notify :update_timing, now_playing.song.duration, now_playing_start_ms
        end
    end

    def time_till_next_song()
        end_time = now_playing_start_ms + now_playing.song.duration
        time_diff = end_time - Time.now.to_f * 1000
    end

    def internal_spotify_add_to_queue(uri)
        url = "me/player/queue"
        url += "?uri=#{uri}"
        RSpotify::User.oauth_post($spotify_user.id, url, {})
    end
end

$JCRADIO_PI = "d94494a49582daf871e6a18d955ea69946163d6f"
