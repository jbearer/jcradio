class SongsStations < ActiveRecord::Base
    belongs_to :song
    belongs_to :station
end

class Station < ActiveRecord::Base
    has_and_belongs_to_many :songs

    def queue
        SongsStations
            .where(station: self)
            .order(:position)
            .map { |relation| relation.song }
    end
end
