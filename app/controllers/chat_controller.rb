class ChatController < ApplicationController
    # GET /chat
    def index
        @message_id = nil

        if logged_in?
            current_user.update last_viewed_chat: Time.now
        end

        respond_to do |format|
            format.html
            format.json {
                render json: ChatMessage
                    .order(created_at: :desc)
                    .limit(params[:limit])
                    .offset(params[:offset])
                    .to_json
            }
        end
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
            message: params[:message],
            song: current_user.station.now_playing.try(:song),
        })

        broadcast :receive_chat, msg

        # Search for mentions
        msg.message.scan(/@([A-Za-z]+)/).each do |mention|
            mention = mention[0]

            user = User.find_by username: mention
            if user
                push(Notification.create({
                    user: user,
                    text: "#{current_user.username} mentioned you: #{msg.message}",
                    url: "/chat/#{msg.id}"
                }))
            elsif mention == "here"
                broadcast :mentioned_by, current_user, msg
            end
        end

        json_ok
    end
end
