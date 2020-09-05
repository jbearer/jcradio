class RecommendationsController < ApplicationController

    include RecommendationsHelper

    # GET /recommendations
    def index
        options = {}

        features.each do |feature|
            if params["use_" + feature[:name]] then
                raw_value = params[feature[:name]]
                value = raw_value.to_f / feature[:scale]
                options["target_" + feature[:name]] = value
            end
        end

        puts options

        symbol_options = options.symbolize_keys

        recommendations = RSpotify::Recommendations.generate(
                limit: 20,
                seed_tracks: [
                    "723paR6LrVISFCXFPf5z57", # above the clouds of pompeii
                    "7mLcjLqiY9rJUA3BQAywiH", # elysium bear's den
                ],
                **symbol_options
            )

        puts recommendations.tracks.length

        @recommendation = recommendations.tracks[0]
    end

    def new
        #@recommendation = Recommendation.new
    end

    # POST /recommendations


    # app/controllers/recommendations_controller.rb
    # ......
    def create
        @recommendation = User.new(params[:recommendation])

        respond_to do |format|
        if @recommendation.save
            format.html { redirect_to @recommendation, notice: 'User was successfully created.' }
            format.js
            format.json { render json: @recommendation, status: :created, location: @recommendation }
        else
            format.html { render action: "new" }
            format.json { render json: @recommendation.errors, status: :unprocessable_entity }
        end
        end
    end

    # def create
    #     puts "heyyyyy"
    #     recommendations = RSpotify::Recommendations.generate(
    #             limit: 20,
    #             seed_tracks: [
    #                 "723paR6LrVISFCXFPf5z57", # above the clouds of pompeii
    #                 "7mLcjLqiY9rJUA3BQAywiH", # elysium bear's den
    #             ]
    #         )

    #     respond_to do |format|
    #         # format.html { redirect_to @recommendation, notice: 'User was successfully created.' }
    #         format.js
    #         # format.json { render json: @recommendation, status: :created, location: @recommendation }
    #     end

    #     # return render json: {random_param_name: "Hello there"}
    # end

end