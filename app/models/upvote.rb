class Upvote < ActiveRecord::Base
    belongs_to :queue_entry
    belongs_to :upvoter, class_name: "User"
end
