require 'open-uri'

class EmojisController < ApplicationController
    before_action :set_emoji, only: [:show]

    # GET /emojis
    def index
        @emojis = Emoji.all.order(:name)
    end

    # GET /emojis/new
    def new
        @emojis = Emoji.all.order(:name)
        render template: "emojis/index"
    end

    # POST /emojis
    def create
        emoji = params[:emoji]

        if emoji[:file].nil?
            if params[:url]
                emoji[:file] = open(params[:url])
            end
        end
        if emoji[:file].nil?
            return json_error "file is required"
        end

        if emoji[:name].nil? or emoji[:name].empty?
            emoji[:name] = params[:default_name]
            Rails.logger.error params[:default_name]
        end
        if emoji[:name].nil?
            return json_error "name is required"
        end
        if not EMOJI_REGEX.match?(":" + emoji[:name] + ":")
            return json_error "invalid emoji name \"#{emoji[:name]}\""
        end

        if not ["image/png", "image/jpeg", "image/gif"].include? emoji[:file].content_type
            return json_error "Unrecognized file type"
        end

        Emoji.create name: emoji[:name], content_type: emoji[:file].content_type, data: emoji[:file].read
        redirect_to "/emojis"
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
