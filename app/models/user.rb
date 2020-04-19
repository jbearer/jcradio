class User < ActiveRecord::Base
    belongs_to :station

    def can_add_to_queue
        station and position == station.users.minimum(:position)
    end
end
