$the_next_letter = '_'
$client_spotifies = {}
class StationsController < ApplicationController

    include SongsHelper
    include StationsHelper

    before_action :set_station, only: [:show, :change_queue_pos, :edit_queue_pos, :plots]

    # GET /stations
    def index
        redirect_to "/stations/1"
    end

    def spotify_create_user
        info = RSpotify::User.new(request.env['omniauth.auth'])
        if not $spotify_user then
            $spotify_user = info
            # Update the song that's currently playing
            TitleExtractorWorker.perform_async(self)
        else
            if not current_user then
                return json_error "user must be logged in to link account"
            else
                $client_spotifies[current_user.username] = info
            end
        end
        redirect_to "/stations/1"
    end

    # GET /stations/1
    def show
    end

    def change_queue_pos
    end

    # POST /stations/1/edit_queue_pos
    def edit_queue_pos
        # print "$$$$$$$$$ Arrived Here $$$$$\n"
        # print "$$$$$$$$$ Arrived Here $$$$$\n"
        # print "$$$$$$$$$ Arrived Here $$$$$\n"
        # print "  InParam: %s\n" % params[:new_queue_pos]


        if not logged_in?
            return json_error "must log in to add to the queue"
        end
        station = current_user.station

        # print "  CurQueuePos: %s\n" % station.queue_pos

        in_param = Integer(params[:new_queue_pos])

        if in_param <= station.queue_max and in_param >= 0
            station.update queue_pos: in_param
        end

        # print "  QueuePos: %s\n" % station.queue_pos


        redirect_to "/stations/1"

        # json_ok

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

    # POST /stations/1/save
    # Save the currently playing song
    def save
        # Upvote in the user's spotify library
        begin
            song = current_user.station.now_playing.song

            if $client_spotifies.key?(current_user.username) then
                song_id = song.source_id
                tracks = RSpotify::Track.find([song_id])

                user = $client_spotifies[current_user.username]
                user.save_tracks!(tracks)

                push(Notification.create({
                    user: current_user,
                    text: "Added to library: " + song.title
                }))
                puts "!!!!!!!! saved song to library !!!!!!!!!!!"
                render json: {success: true, saved: true}
            else
                puts "!!!!!!!! user not associated with spotify acct !!!!!!"
            end
        rescue => e
            puts "!!!!!!!! failed to save song !!!!!!!!!!!"
            Rails.logger.error e.message
            e.backtrace.each { |line| Rails.logger.error line }
        end

        render json: {success: true, saved: false} # is it successful though?
    end

    # POST /stations/1/refresh
    # Refresh the now_playing window
    def refresh
        if $the_background_thread.status == 'sleep' then
            $the_background_thread.wakeup
        end

        # call update_timing, in case the song didn't change, but the
        # end time did change
        Station.find(1).update_timing_stats

        render json: { success: true }
    end

    private
        def set_station
          @station = Station.find(params[:id])
        end

    # GET /stations/1/plots
    def plots

    end

end

################ Background process to update song title
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
          $the_background_thread = Thread.new { new.perform(*args) }
        end
      end

      def perform(*)
        raise NotImplementedError
      end
    end
  end

  class TitleExtractorWorker
    include Magique::Worker

    # Background thread which monitors the current playing song

    # If no song is playing, sleep until woken up
    # If the current song is different from the last song, update the song,
    #   Then sleep until you calculate it to be over
    # If the current song is the same as the last song, sleep until it's over
    def perform(station)

        last_song = nil
        while true
            begin
                player = $spotify_user.player
                if not player or not player.playing?
                    sleep   # until awoken
                    next
                end

                curr_song = player.currently_playing
                if (not last_song) or (curr_song.id != last_song.id) then
                    # We have a new song
                    last_song = curr_song
                    # Update the queue with the new song
                    Station.find(1).next_song(Song.get("Spotify", curr_song.id))
                    Station.find(1).update_timing_stats()
                end

                time_diff = Station.find(1).time_till_next_song().to_f / 1000

            rescue => e
                Rails.logger.error e.message
                e.backtrace.each { |line| Rails.logger.error line }
                time_diff = 5
            end

            # Lowerbound at 1 so we don't spam spotify tooo much
            sleep_time = time_diff > 1 ? time_diff : 1
            sleep(sleep_time)
        end
    end
  end
#device id for my phone for testing
$daniels_phone="11b8da8cb3a8144bda76d1f50599ed0b98a09ee1"
