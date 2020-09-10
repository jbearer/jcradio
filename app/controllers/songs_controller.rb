class SongsController < ApplicationController
    # GET /songs
    def index
        @songs = []
        @query = nil
        render template: "songs/index", :locals => {
            :songs => @songs
        }
    end

    # GET /songs/search
    #   query: string of keywords
    def search
        @songs = Song.spotify_search(params[:query])
        @query = params[:query]

        render template: "songs/index", :locals => {
            :songs => @songs
        }
    end

    # GET /songs/search
    #   query: string of keywords
    #   Returns javascript for inline search
    def inline_search
        @songs = Song.spotify_search(params[:query])

        respond_to do |format|
            format.js { render "search", :locals => {
                            :songs => @songs }}
        end
    end
end
