class BuddyController < ApplicationController

    # GET /buddy
    def index
        @buddy_on = Buddy.member?(@station)
        @buddy_taste = @station.buddy_taste
        @buddy_max_songs = @station.buddy_max_songs
        @buddy_users = Buddy.taste_sources
        @spotify_users = SpotifyAccounts.linked_usernames
    end

    # POST /buddy/configure
    #   buddy_on: "true" | "false"
    #   buddy_taste[]: "<Radio|username>_<played|upvoted|spotify>"
    #   buddy_max_songs: integer
    def configure
        @station.update buddy_taste: Array(params[:buddy_taste]),
                        buddy_max_songs: params[:buddy_max_songs].to_i

        if params[:buddy_on] == "true"
            Buddy.join(@station)
        else
            Buddy.leave(@station)
        end

        redirect_to "/buddy"
    end
end
