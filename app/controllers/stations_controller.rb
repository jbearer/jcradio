
$notify_laggard_user = true # flag to notify user once queue is almost empty

require 'yaml'

class StationsController < ApplicationController

    include SongsHelper
    include StationsHelper

    # GET /stations
    def index
        redirect_to "/stations/1"
    end

    def spotify_create_user
        info = RSpotify::User.new(request.env['omniauth.auth'])
        if not $spotify_user then
            $spotify_user = info

            file_path = File.join(Dir.home, "/jcradio/.nothingtoseehere.yml")
            logger.info("$$$$$$$$$$$$$$$$$$$$$$$$$$$\n")
            logger.info(file_path)
            logger.info("$$$$$$$$$$$$$$$$$$$$$$$$$$$\n")

            # Log user to file (easy login next time, though not secure :3)
            File.write(file_path, $spotify_user.to_hash.to_yaml)

            # Update the song that's currently playing
            TitleExtractorWorker.perform_async(self)
            redirect_to "/sessions"
        else
            if not current_user then
                return json_error "user must be logged in to link account"
            else
                $client_spotifies[current_user.username] = info
                $spotify_libraries_cached[current_user.username] = [Time.at(0), []] # Timestamp, and song listS
            end
            redirect_to "/stations/1"
        end
    end

    # POST /stations/1/user_spotify_logout
    def user_spotify_logout
        $client_spotifies.delete(current_user.username)
        redirect_to "/sessions"
    end

    # GET /stations/1
    def show
        # Set the next_letter properly, if currently unset
        if @station and $the_next_letter == "_" or $the_next_letter == ""
            $the_next_letter = @station.queue[@station.queue_max - @station.queue_pos].song.next_letter
        end

        # refresh the now_playing
        refresh_now_playing_and_stuff

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


    def buddy_add_song

        if @station.users.order(:position)[0] != User.find_by(username: "Buddy")
            return
        end

        puts "****************************"
        puts "Buddy's turn!"
        puts "NextLetter = #{$the_next_letter}"
        puts "****************************"

        # Only Buddy alone
        if @station.users.length == 1
            if @station.queue_max - @station.queue_pos >= 1
                puts "****************************"
                puts "Buddy is lonely. Buddy will wait for smaller queue"
                puts "****************************"
                return
            end
        end

        # Queue long, waiting
        if @station.queue_max - @station.queue_pos > 10
            puts "****************************"
            puts "Too many songs in the queue. Buddy will wait!"
            puts "****************************"
            return
        end

        # Get Buddy user
        @buddy = User.find_by(username: "Buddy")

        ## Add a song
        if $buddy_taste == "radio_played"
            index = QueueEntry.where.not(position: nil) # TODO Ask jeb for optimization
            results = index.order("queue_entries.id DESC").map {|q| q.song}

            songs = []
            results.each do |s|
                if s.first_letter == $the_next_letter then
                    songs.append(s)
                end
            end

        # Default to All songs on radio
        else
            puts "*******************************************************"
            puts " Sorry, buddy_taste='#{$buddy_taste}'' isn't supported yet"
            puts "*******************************************************"

            ## Copy from above, Default to All Songs on Radio
            index = QueueEntry.where.not(position: nil) # TODO Ask jeb for optimization
            results = index.order("queue_entries.id DESC").map {|q| q.song}
            songs = []
            results.each do |s|
                if s.first_letter == $the_next_letter then
                    songs.append(s)
                end
            end
        end

        # Get random number for the song
        chosen_song = songs[rand(songs.length)]
        err_str = @station.queue_song(chosen_song, @buddy, false)

        if err_str != "" then
            puts "\n\n\n\n****************************"
            puts "err: #{err_str}"
            puts "****************************"
            return
        end

        @buddy.update position: @station.users.maximum(:position) + 1

        # Notify the next user that it's their turn to pick a song.
        next_user = @station.users.order(:position)[0]
        $the_next_letter = chosen_song.next_letter.capitalize()[0]

        if next_user != @buddy then
            broadcast :next_up, next_user, $the_next_letter
        end

        puts "****************************"
        puts index.length
        puts index[0]
        puts index[0].song
        puts index[0].song.title
        puts index[0].song.first_letter
        puts "****************************"
        puts songs.length
        puts chosen_song.title
        puts "err: #{err_str}"
        puts "****************************"


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
        err_str = station.queue_song(song, current_user, params[:was_recommended])

        song.update last_played: Time.now.to_f * 1000 # ms since 01/01/1970

        if err_str != "" then
            return json_error err_str
        end

        current_user.update position: station.users.maximum(:position) + 1

        # Notify the next user that it's their turn to pick a song.
        next_user = station.users.order(:position)[0]
        $the_next_letter = params[:song_next_letter].capitalize()[0]

        if next_user != current_user then
            broadcast :next_up, next_user, $the_next_letter
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

    # POST /stations/1/skip_song
    # Skip to the next song on Spotify
    def skip_song
        puts "\n\n************"
        puts "Skip song on Spotify"
        puts "************\n\n"

        $spotify_user.player.next

        redirect_to "/stations/1"
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

                $spotify_libraries_cached[current_user.username][0] = Time.at(0) # Reset cache

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
        refresh_now_playing_and_stuff

        render json: { success: true }
    end

    def refresh_now_playing_and_stuff
        if $the_background_thread.status == 'sleep' then
            $the_background_thread.wakeup
        end

        # Check if it's Buddy's turn
        buddy_add_song

        # If one song in queue, notify next user
        if @station.queue_max - @station.queue_pos == 0 && $notify_laggard_user
            $notify_laggard_user = false # unset the flag
            next_user = @station.users.order(:position)[0]
            if next_user != User.find_by(username: "Buddy")
                # Notify the next user that it's their turn to pick a song.
                if next_user != @buddy then
                    broadcast :next_up, next_user, $the_next_letter
                    puts "****************************"
                    puts "****************************"
                    puts "notify user: #{next_user.username}"
                    puts "****************************"
                    puts "****************************"
                end
            end
        end

        # call update_timing, in case the song didn't change, but the
        # end time did change
        @station.update_timing_stats
    end

    # GET /stations/1/plots
    def plots

    end

end

