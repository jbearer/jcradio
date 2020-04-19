class StationsController < ApplicationController
    before_action :set_station, only: [:show]

    # GET /stations
    def index
        redirect_to "/stations/1"
    end

    # GET /stations/1
    def show
    end

    # PUT /stations/1
    #   song_id: string
    # Add the song to the queue.
    def update
        if not logged_in?
            return json_error "must log in to add to the queue"
        end

        station = current_user.station
        if not station
            return json_error "join a station to add to the queue"
        end

        if current_user.position != station.users.minimum(:position)
            return json_error "it's not your turn to add to the queue"
        end

        song = Song.find(params[:song_id])
        if !song
            return json_error "no such song"
        end

        station.queue_song song
        current_user.update position: (station.users.maximum(:position) || 0) + 1

        json_ok
    end

    private
        def set_station
          @station = Station.find(params[:id])
        end
end
