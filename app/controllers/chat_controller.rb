class ChatController < ApplicationController
    after_action :update_last_viewed_chat

    # GET /chat
    def index
        @message_id = nil

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

        # Search for emojis
        text = params[:message].gsub(/:[A-Za-z_]+:/) do |match|
            # Remove enclosing colons
            name = match.slice(1..match.length-2)
            Rails.logger.error name

            emoji = Emoji.find_by name: name
            if emoji.nil?
                match
            else
                <<-HTML
                    <span class="emoji">
                        <image src="/emojis/#{emoji.id}" width="30">
                        <span class="emojiname">#{match}</span>
                    </span>
                HTML
            end
        end

        msg = ChatMessage.create({
            sender: current_user,
            message: text,
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

    private
        def update_last_viewed_chat
            if logged_in?
                current_user.update last_viewed_chat: Time.now
            end
        end
end
