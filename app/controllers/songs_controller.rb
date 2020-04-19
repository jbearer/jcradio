class SongsController < ApplicationController
    # GET /songs
    def index
        @songs = []
    end

    # GET /songs/search
    #   title: optional string
    #   album: optional string
    #   artist: optional string
    def search
        @songs = Song.where(params.delete_if{|k,v| v.empty?}.permit(:title, :album, :artist))
            # TODO look up from Spotify; our database is only populated _after_ a
            # song has been searched in Spotify.
        render template: "songs/index"
    end

end
