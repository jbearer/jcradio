class User < ActiveRecord::Base
    belongs_to :station
    has_many :queue_entries, inverse_of: :selector, foreign_key: :selector_id
    has_many :received_upvotes, through: :queue_entries, source: :upvotes
    has_many :given_upvotes, class_name: "Upvote", inverse_of: :upvoter, foreign_key: :upvoter_id
    has_many :pending_notifications, class_name: "Notification"

    def can_add_to_queue
        station and position == station.users.minimum(:position)
    end

    def to_h
        {name: username, id: id}
    end

    def as_json(options=nil)
        super only: [:id, :username]
    end

    def has_upvoted?(selection)
        not (given_upvotes.find_by queue_entry: selection).nil?
    end

    def subscribed?
        LiveRPC.server? id
    end

    def notify(function, *args)
        LiveRPC.call id, function, args
    end
end
