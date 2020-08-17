class ChatController < ApplicationController
    # GET /chat
    def index
        @message_id = nil
    end

    # GET /chat/:id
    def show
        @message_id = params[:id]
        render template: "chat/index"
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

        # Search for mentions
        msg.message.scan(/@([^\s@]+)/).each do |mention|
            mention = mention[0]

            user = User.find_by username: mention
            if user
                push(Notification.create({
                    user: user,
                    text: "#{current_user.username} mentioned you: #{msg.message}",
                    url: "/chat/#{msg.id}"
                }))
            elsif mention == "here"
                broadcast :mentioned_by, current_user, msg.message
            end
        end

        json_ok
    end
end
