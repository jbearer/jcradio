class ChatMessage < ActiveRecord::Base
    belongs_to :sender, class_name: "User"
    belongs_to :song

    def as_json(options=nil)
        d = super include: [:sender, :song]
        if version < 1
            # Version 0 messages are not HTML-escaped in the database, so we need to do it here
            # before we send it to the front-end.
            d["message"] = CGI::escapeHTML(d["message"])
        end
        d
    end
end
