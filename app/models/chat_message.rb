class ChatMessage < ActiveRecord::Base
    belongs_to :sender, class_name: "User"

    def as_json(options=nil)
        super include: [:sender]
    end
end
