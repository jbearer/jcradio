class StationsController < ApplicationController
    before_action :set_station, only: [:show]

    # GET /stations
    def index
        redirect_to "/stations/1"
    end

    # GET /stations/1
    def show
    end

    private
        def set_station
          @station = Station.find(params[:id])
        end
end
