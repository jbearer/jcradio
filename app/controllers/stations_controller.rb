class StationsController < ApplicationController
    before_action :set_station, only: [:show]

    # GET /stations
    def index
        redirect_to "/stations/1"
    end

    def spotify_create_user
        # TODO: Move to the appropriate place
        # TODO: don't make this a global variable. probably a static class
        # variable.
        # TODO: Make "Sign in with Spotify" button go away if user exists
        $spotify_user = RSpotify::User.new(request.env['omniauth.auth'])
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

        station.spotify_queue_song(params[:title], params[:uri])

        # song = Song.find(params[:song_id])
        # if !song
        #     return json_error "no such song"
        # end

        # station.queue_song song, current_user
        current_user.update position: station.users.maximum(:position) + 1

        # Notify the next user that it's their turn to pick a song.
        next_user = station.users.order(:position)[0]
        if next_user.subscription
            subscription = JSON.parse(next_user.subscription)
            Rails.logger.error subscription
            Webpush.payload_send({
                message: "Hey #{next_user.username}! It's your turn to pick a song on jcradio!",
                endpoint: subscription["endpoint"],
                p256dh: subscription["keys"]["p256dh"],
                auth: subscription["keys"]["auth"],
                api_key: "" # TODO we need this for Chrome
            })
        end

        json_ok
    end

    # GET /stations/1/next
    # Skip to the next queued song.
    #
    # Eventually, this method should be called by the server-side streaming engine whenever it
    # finishes broadcasting a song, and it should not be exposed to an API endpoint. For now, since
    # the streaming engine does not exist, we let the user who selected the current song go to the
    # next song, for testing purposes.
    def next
        if not logged_in?
            return json_error "must log in to skip a song"
        end

        station = current_user.station
        if not station
            return json_error "join a station to skip songs"
        end

        if station.now_playing.selector != current_user
            return json_error "you can't skip a song you didn't add"
        end

        station.update now_playing: station.queue[0]
        station.now_playing.update station: nil if station.now_playing

        return json_ok
    end

    private
        def set_station
          @station = Station.find(params[:id])
        end
end
