$the_next_letter = '_'
class StationsController < ApplicationController

    include SongsHelper

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

        song = Song.get "Spotify", params[:source_id]
        err_str = station.queue_song(song, current_user)

        song.update last_played: Time.now.to_f * 1000 # ms since 01/01/1970

        if err_str != "" then
            return json_error err_str
        end

        current_user.update position: station.users.maximum(:position) + 1

        # Notify the next user that it's their turn to pick a song.
        next_user = station.users.order(:position)[0]
        $the_next_letter = params[:song_next_letter].capitalize()[0]
        # $the_next_letter = SongsHelper.calculate_next_letter(params[:title])
        broadcast :next_up, next_user, $the_next_letter

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

        curr_song = nil

        while true
            sleep 5

            begin

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

                this_song = $spotify_user.player.currently_playing

                if (not curr_song) or (this_song.name != curr_song.name)
                    puts "@@@@@@@@@@@@@@@@@@@@@@@@@@"
                    puts "@@@ PRINTING SONG INFO @@@"
                    puts "@@@@@@@@@@@@@@@@@@@@@@@@@@"

                    print "Song: "
                    puts this_song.name
                    print "Artist: "
                    puts this_song.artists.first.name

                    curr_song = this_song

                    begin
                        # Update the queue with the new song.
                        Station.find(1).next_song(Song.get("Spotify", this_song.id))
                    rescue => e
                        Rails.logger.error e.message
                        e.backtrace.each { |line| Rails.logger.error line }
                    end
                end
            rescue => e
                puts "!!!!!!!! failed to get song info !!!!!!!!!!!!"
                Rails.logger.error e.message
                e.backtrace.each { |line| Rails.logger.error line }
            end
        end
    end
  end
#device id for my phone for testing
$daniels_phone="11b8da8cb3a8144bda76d1f50599ed0b98a09ee1"
