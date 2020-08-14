module ChatHelper
    def authored?(msg)
        logged_in? and current_user == msg.sender
    end
end
