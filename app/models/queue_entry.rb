class QueueEntry < ActiveRecord::Base
    belongs_to :song
    belongs_to :station
    belongs_to :selector, class_name: "User"
    has_many :upvotes

    # ruby can't serialize bools
    def rec
        if self.was_recommended then 1 else 0 end
    end

    def as_json(options=nil)
        super include: [:song, :selector], only: [:id, :position], methods: [:rec]
    end
end
