class EmojisController < ApplicationController
    before_action :set_emoji, only: [:show]

    # GET /emojis/new
    def new
    end

    # POST /emojis
    def create
        emoji = params[:emoji]

        if not ["image/png", "image/jpeg", "image/gif"].include? emoji[:file].content_type
            return json_error "Unrecognized file type"
        end

        Emoji.create name: emoji[:name], content_type: emoji[:file].content_type, data: emoji[:file].read
        redirect_to "/chat"
    end

    # GET /emojis/:id
    def show
        send_data @emoji.data, type: @emoji.content_type, disposition: :inline
    end

    private
        def set_emoji
          @emoji = Emoji.find(params[:id])
        end
end
