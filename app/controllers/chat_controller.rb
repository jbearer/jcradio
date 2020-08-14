class ChatController < ApplicationController
    # GET /chat
    def index
    end

    # POST /chat
    #   message: string
    def create
        if not logged_in?
            return json_error "You must be logged in to chat"
        end

        msg = ChatMessage.create({
            sender: current_user,
            message: params[:message]
        })

        broadcast :receive_chat, msg

        json_ok
    end
end
