class RecommendationsController < ApplicationController

    include RecommendationsHelper
    include SongsHelper

    # GET /recommendations
    def suggest
        source_ids = params[:source_id]
        categories = params[:category]

        ##### UGH I give up on trying to do the error checking from spotify
        error_song = nil
        if source_ids == nil or source_ids.length == 0
            error_song = Song.new(title: "ERROR", artist: "No seeds!", album: "don't add me", duration: "1")
        elsif source_ids.length > 5 then
            error_song = Song.new(title: "ERROR", artist: "More than five seeds!", album: "sad", duration: "1")
        end

        if error_song then
            respond_to do |format|
                format.js { render "suggest", :locals => {
                    :songs => [error_song]}}
            end
            return
        end
        #####

        options = {}

        features.each do |feature|
            if params["use_" + feature[:name]] then
                raw_value = params[feature[:name]]
                value = raw_value.to_f / feature[:scale]
                # Some spotify values must be integers.
                # If so, then "value" will be an integer
                if value.to_i == value then
                    value = value.to_i
                end
                options["target_" + feature[:name]] = value
            end
        end

        symbol_options = options.symbolize_keys

        seed_tracks = []
        seed_artists = []

        source_ids.zip(categories) do |id, cat|
            if cat == "track" then
                seed_tracks += [id]
            elsif cat == "artist" then
                seed_artists += [id]
            else
                fail "seed was neither track nor artist"
            end
        end

        recommendations = RSpotify::Recommendations.generate(
            limit: 100,
            seed_tracks: seed_tracks,
            seed_artists: seed_artists,
            **symbol_options
        )

        songs = []

        recommendations.tracks.each do |rec|
            if params[:query] == "" or params[:query] == SongsHelper.first_letter(rec.name) then
                songs.append(SongsHelper.get_or_create_from_spotify_record rec)
            end
        end

        respond_to do |format|
            format.js { render "suggest", :locals => {
                :songs => songs}}
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
        idx = params[:last_counter].to_i

        entry = nil

        if source == "my_spotify_library" then

            client_spotify = $client_spotifies[current_user.username]
            if not client_spotify then
                fail "Not logged into spotify"
            end

            # I _think_ that tracks are sorted in order of saved, but it's not in the docs
            if recency == "last" then
                offset = idx
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
                entry = index.order("queue_entries.id DESC")[idx]
            else
                entry = index.order('RANDOM()')[idx]
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