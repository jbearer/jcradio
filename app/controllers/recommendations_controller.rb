class RecommendationsController < ApplicationController

    include RecommendationsHelper
    include SongsHelper

    # GET /recommendations
    def suggest
        options = {}

        features.each do |feature|
            if params["use_" + feature[:name]] then
                raw_value = params[feature[:name]]
                value = raw_value.to_f / feature[:scale]
                options["target_" + feature[:name]] = value
            end
        end

        symbol_options = options.symbolize_keys

        seed_tracks = []
        seed_artists = []

        source_ids = params[:source_id]
        categories = params[:category]

        source_ids.zip(categories) do |id, cat|
            if cat == "track" then
                seed_tracks += [id]
            elsif cat == "artist" then
                seed_artists += [id]
            else
                fail "seed was neither track nor artist"
            end
        end

        if not params[:search]
            # Log a useful message
            return
        end
        target_letter = params[:search][0].upcase

        recommendations = RSpotify::Recommendations.generate(
            limit: 100,
            seed_tracks: seed_tracks,
            seed_artists: seed_artists,
            **symbol_options
        )

        recommendations.tracks.each do |rec|
            if SongsHelper.first_letter(rec.name) == target_letter then
                @recommendation = rec
                break
            end
        end

        if not @recommendation
            # Log useful message
            return
        end

        puts recommendations.tracks.length
        puts @recommendation.name

        respond_to do |format|
            format.js
        end
    end

    def search

        if params[:category] == "track" then
            @search_artists = nil
            @search_songs = Song.spotify_search(params[:query])
        else
            @search_artists = RSpotify::Artist.search(params[:query])
            @search_songs = nil
        end

        # Runs the code in recommendations/search.js.erb, which updates the partial
        # in recommendations/_search_results.html.erb
        respond_to do |format|
            format.js
        end
    end

    # Add a seed based on the station or user's history
    def add_seed
        recency = params[:recency]
        category = params[:category]
        source = params[:source]

        entry = nil

        if source == "my_spotify_library" then

            client_spotify = $client_spotifies[current_user.username]
            if not client_spotify then
                fail "Not logged into spotify"
            end

            # I _think_ that tracks are sorted in order of saved, but it's not in the docs
            if recency == "last" then
                offset = 0
            else
                total = spotify_number_of_tracks(client_spotify.id)
                offset = rand(0..total-1)
            end
            track = client_spotify.saved_tracks(limit: 1, offset: offset).first

            if category == "track" then
                name = track.name
                source_id = track.id
            else
                artist = track.artists.first
                name = artist.name
                source_id = artist.id
            end

        else
            index = nil

            if source == "my_chosen_songs" then
                index = QueueEntry.where(selector_id: current_user.id)
            elsif source == "my_upvoted_songs" then
                index = QueueEntry.select("queue_entries.*, upvotes.*").joins(:upvotes)
                index = index.where("upvotes.upvoter_id = ?", current_user.id)
            else # all songs
                index = QueueEntry.select("*")
            end

            if recency == "last" then
                entry = index.order("queue_entries.id DESC").first
            else
                entry = index.order('RANDOM()').first
            end

            if category == "track" then
                name = entry.song.title
                source_id = entry.song.source_id
            else
                # unfortunately we don't store the artist source_id.  TODO: Add to the index
                sourceTrack = RSpotify::Track.find(entry.song.source_id)
                artist = sourceTrack.artists.first
                name = artist.name
                source_id = artist.id
            end
        end

        respond_to do |format|
            format.js { render "add_seed", :locals => {
                                :name => name, :source_id => source_id, :category => category}}
        end
    end

    def new
        #@recommendation = Recommendation.new
    end


end