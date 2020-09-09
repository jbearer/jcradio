class SongsController < ApplicationController
    # GET /songs
    def index
        @songs = []
        @query = nil
    end

    # GET /songs/search
    #   query: string of keywords
    def search
        @songs = Song.spotify_search(params[:query])
        @query = params[:query]

        respond_to do |format|
            format.js { render "search", :locals => {
                            :songs => @songs }}
        end
    end

end
