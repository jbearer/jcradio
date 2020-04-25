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
end
