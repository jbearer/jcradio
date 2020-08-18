class QueueEntry < ActiveRecord::Base
    belongs_to :song
    belongs_to :station
    belongs_to :selector, class_name: "User"
    has_many :upvotes

    def as_json(options=nil)
        super include: [:song]
    end
end
