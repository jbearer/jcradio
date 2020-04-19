class SongsStations < ActiveRecord::Base
    belongs_to :song
    belongs_to :station
end

class Station < ActiveRecord::Base
    has_and_belongs_to_many :songs
    belongs_to :now_playing, class_name: "Song"
    has_many :users

    def queue
        SongsStations
            .where(station: self)
            .order(:position)
            .map { |relation| relation.song }
    end
end
