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
            if not SpotifyAccounts.linked?(current_user)
                raise IndexError, "Not logged into spotify"
            end
            results = SongsHelper.get_or_create_from_spotify_record(SpotifyAccounts.library(current_user))
            songs = results.select do |s|
                params[:query] == "" or params[:query] == SongsHelper.first_letter(s.title)
            end
        else
            # One query for distinct songs, most recently queued first; the old
            # QueueEntry.map { |q| q.song } issued one song query per entry.
            joins = source == "my_upvoted_songs" ? { queue_entries: :upvotes } : :queue_entries
            index = Song.joins(joins).where.not(queue_entries: {position: nil})\
                    .where(first_letter: params[:query])
            if source == "my_chosen_songs" then
                index = index.where(queue_entries: {selector_id: current_user.id})
            elsif source == "my_upvoted_songs" then
                index = index.where(upvotes: {upvoter_id: current_user.id})
            end
            songs = index.group("songs.id").order("MAX(queue_entries.id) DESC").limit(500).to_a
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
