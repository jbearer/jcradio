class User < ActiveRecord::Base
    belongs_to :station

    def can_add_to_queue
        station and position == station.users.minimum(:position)
    end

    def to_h
        {name: username, id: id}
    end
end
