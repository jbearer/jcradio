class ChatMessage < ActiveRecord::Base
    belongs_to :sender, class_name: "User"
    belongs_to :song

    def as_json(options=nil)
        super include: [:sender, :song]
    end
end
