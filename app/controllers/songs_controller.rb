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

        if source == "my_spotify_library" then
            client_spotify = $client_spotifies[current_user.username]
            if not client_spotify then
                raise IndexError "Not logged into spotify"
            end
            spotify_songs = spotify_get_all_songs(client_spotify)
            results = SongsHelper.get_or_create_from_spotify_record(spotify_songs, true)
            songs = []
            results.each do |s|
                if params[:query] == "" or params[:query] == SongsHelper.first_letter(s.title) then
                    songs.append(s)
                end
            end
        else
            if source == "my_chosen_songs" then
                index = QueueEntry.all.joins(:song).where.not(position: nil).where(selector: current_user.id)\
                        .where(songs: {first_letter: params[:query]})
            elsif source == "my_upvoted_songs" then
                index = QueueEntry.all.joins(:upvotes).joins(:song).where.not(position: nil)\
                        .where(upvotes: {upvoter_id: current_user.id}).where(songs: {first_letter: params[:query]})
            else
                index = QueueEntry.all.joins(:song).where.not(position: nil).where(songs: {first_letter: params[:query]})
            end
            songs = index.limit(500).order("queue_entries.id DESC").map {|q| q.song}
            songs = songs.uniq # Filter out duplicates (keeps most recent, b/c ordered by desc)
            # Arn arbitrary large limit.  Hopefully, in the future the "More Results"
            # option will work
        end

        respond_to do |format|
            format.js {render "search", :locals => {
                :songs => songs }}
        end
    end

    # GET /songs/birth
    def birth

    end

end
