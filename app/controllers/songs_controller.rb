class SongsController < ApplicationController
    include RecommendationsHelper

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

        render template: "songs/search", :locals => {
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

    # GET /songs/browse
    def browse
        source = params[:source]

        client_spotify = $client_spotifies[current_user.username]
        if not client_spotify then
            fail "Not logged into spotify"
        end

        if source == "my_spotify_library" then
            spotify_songs = spotify_get_all_songs(client_spotify)
            results = spotify_songs.map{|s| SongsHelper.get_or_create_from_spotify_record s}
        else
            if source == "my_chosen_songs" then
                index = QueueEntry.where(selector_id: current_user.id)
            elsif source == "my_upvoted_songs" then
                index = QueueEntry.select("queue_entries.*, upvotes.*").joins(:upvotes)
                index = index.where("upvotes.upvoter_id = ?", current_user.id)
            else
                index = QueueEntry.where.not(position: nil)
            end
            results = index.limit(500).order("queue_entries.id DESC").map {|q| q.song}
            # Arn arbitrary large limit.  Hopefully, in the future the "More Results"
            # option will work
        end

        songs = []

        results.each do |s|
            if params[:query] == "" or params[:query] == SongsHelper.first_letter(s.title) then
                songs.append(s)
            end
        end

        respond_to do |format|
            format.js {render "search", :locals => {
                :songs => songs }}
        end
    end

end
