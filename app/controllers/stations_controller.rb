class StationsController < ApplicationController
    before_action :set_station, only: [:show]

    # GET /stations
    def index

        # This is done hackily for now:
        #   Hard code a user, and save as a global variable $spotify_user
        # TODO:
        #   Put this functionality in a different place. maybe a login button?
        #   Automatically log the user in to get the token, with a username and password
        #   Use the refresh token
        #   Put this in an initialization place instead
        #   Don't commit the secret to the repo (this isn't a big deal since we can reset the secret)

        $spotify_user = RSpotify::User.new({
            'id' => "1285766091",
            'credentials' => {
              'token' => "BQBhNG08y4Fs57MR9dB5aP78Ox7lUCCegd9fCML6zWQNLYLcvm0vEhGS8e_xNwcl069BF_ZpGGXVSqdHeEjBdK7StfLs3vzXg_UJT3uwS4U_-AGvyxLb58VjmXDSkBH6klZvXefgTf6PcpG0BbB7Q9yShnHPxb6MSSQlX2_BZmPrImEcfaGxRUxcJTLnU03S4owlNnAUcYulJf8jMG60Vw",
              'refresh_token' => "AQDq3nkvfQdX_mPbnq8U9D_ChWG4DSQF2rIGbMflhrb4s362TEQsfVEGCvmILB-5fOa1YmD-NScAp3wDpdQeDRHZut1SFGH-ii_ksNkb5T60IsQuL0M3kELwlK0jN8wMPU4"
            }
          })


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

        station.queue_song song, current_user
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
