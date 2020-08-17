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
        #@songs = Song.fuzzy_search(params[:query].split)
            # TODO look up from Spotify; our database is only populated _after_ a
            # song has been searched in Spotify.
        render template: "songs/index"
    end

end
