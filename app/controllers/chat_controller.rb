class ChatController < ApplicationController
    after_action :update_last_viewed_chat

    before_action :set_station
    private
        def set_station
            @station = Station.find 1
        end

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

        text = CGI::escapeHTML params[:message]

        # Search for emojis
        text = text.gsub(EMOJI_REGEX) do |match|
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

        # Search for mentions and replace them with highlighted links
        mentions = []
        text = text.gsub(/@[A-Za-z]+/).each do |mention|
            # Remove the "@".
            username = mention.slice(1..mention.length)

            user = User.find_by username: username
            if user
                mentions.push user
                "<a href=\"/users/#{user.id}\" class=\"mention\">#{username}</a>"
            elsif username == "here"
                mentions.push nil
                "<a href=\"/users\" class=\"mention\">#{username}</a>"
            else
                mention
            end
        end

        msg = ChatMessage.create({
            sender: current_user,
            message: text,
            song: current_user.station.now_playing.try(:song),
            version: 1
        })

        # Send mention notifications
        mentions.each do |user|
            if user
                push(Notification.create({
                    user: user,
                    text: "#{current_user.username} mentioned you: #{msg.message}",
                    url: "/chat/#{msg.id}"
                }))
            else
                broadcast :mentioned_by, current_user, msg
            end
        end

        broadcast :receive_chat, msg

        json_ok
    end

    private
        def update_last_viewed_chat
            if logged_in?
                current_user.update last_viewed_chat: Time.now
            end
        end
end
