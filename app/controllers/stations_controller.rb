class StationsController < ApplicationController
    before_action :set_station, only: [:show]

    # GET /stations
    def index
        redirect_to "/stations/1"
    end

    def spotify_create_user
        $spotify_user = RSpotify::User.new(request.env['omniauth.auth'])
        # Update the song that's currently playing
        TitleExtractorWorker.perform_async(self)
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

        err_str = station.spotify_queue_song(params[:title], params[:uri])

        if err_str != "" then
            return json_error err_str
        end

        current_user.update position: station.users.maximum(:position) + 1

        # Notify the next user that it's their turn to pick a song.
        next_user = station.users.order(:position)[0]
        notify next_user, :on_my_turn

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

################ Background process to update song title
## Note: this currently is called from anywhere
# https://blog.appsignal.com/2019/04/02/background-processing-system-in-ruby.html
module Magique
    module Worker
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def perform_now(*args)
          new.perform(*args)
        end
        def perform_async(*args)
          Thread.new { new.perform(*args) }
        end
      end

      def perform(*)
        raise NotImplementedError
      end
    end
  end

  class TitleExtractorWorker
    include Magique::Worker

    def perform(station)

        while true
            sleep 5

            if not $spotify_user.player
                puts "@@@@@@@@@@@@@@@@@"
                puts "@@@ NO PLAYER @@@"
                puts "@@@@@@@@@@@@@@@@@"
                next
            end

            if not $spotify_user.player.playing?
                puts "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
                puts "@@@ NOT CURRENTLY PLAYING @@@"
                puts "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
                next
            end

            playing_info = $spotify_user.player.currently_playing

            puts "@@@@@@@@@@@@@@@@@@@@@@@@@@"
            puts "@@@ PRINTING SONG INFO @@@"
            puts "@@@@@@@@@@@@@@@@@@@@@@@@@@"

            print "Song: "
            puts playing_info.name
            print "Artist: "
            puts playing_info.artists.first.name

        end
    end
  end
#device id for my phone for testing
$daniels_phone="11b8da8cb3a8144bda76d1f50599ed0b98a09ee1"
