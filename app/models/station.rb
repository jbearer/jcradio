class SongsStations < ActiveRecord::Base
    belongs_to :song
    belongs_to :station
    belongs_to :selector, class_name: "User"
end

class Station < ActiveRecord::Base
    has_and_belongs_to_many :songs
    belongs_to :now_playing, class_name: "SongsStations"
    has_many :users

    def queue
        SongsStations.where(station: self).order(:position)
    end

    def queue_song(song, selector)
        if self.now_playing
            # Queue the song
            SongsStations.create song: song, station: self,
                position: (queue.maximum(:position) || 0) + 1,
                selector: selector
        else
            # Play it immediately
            update now_playing: (SongsStations.create song: song, selector: selector)
        end
    end

    def spotify_queue_song(song, uri)
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
            internal_spotify_add_to_queue(uri)
        else
            # Otherwise, play this song immediately
            # TODO: Causes RestClient::NotFound :( :( :(
            # player.play_track(uri)
            return "Spotify not Playing. (Might be logged in as wrong Spotify)"
        end

        return ""
    end

    def internal_spotify_add_to_queue(uri)
        url = "me/player/queue"
        url += "?uri=#{uri}"
        RSpotify::User.oauth_post($spotify_user.id, url, {})
    end
end
