class RecommendationsController < ApplicationController

    include RecommendationsHelper

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

        recommendations = RSpotify::Recommendations.generate(
            limit: 20,
            seed_tracks: seed_tracks,
            seed_artists: seed_artists,
            **symbol_options
        )

        puts recommendations.tracks.length

        @recommendation = recommendations.tracks[0]

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

    def new
        #@recommendation = Recommendation.new
    end


end