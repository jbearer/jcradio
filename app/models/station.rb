class SongsStations < ActiveRecord::Base
    belongs_to :song
    belongs_to :station
end

class Station < ActiveRecord::Base
    has_and_belongs_to_many :songs
    belongs_to :now_playing, class_name: "Song"
    has_many :users

    def queue
        song_relations.map { |relation| relation.song }
    end

    def queue_song(song)
        SongsStations.create song: song, station: self,
            position: (song_relations.maximum(:position) || 0) + 1
    end

    private
        def song_relations
            SongsStations.where(station: self).order(:position)
        end
end
