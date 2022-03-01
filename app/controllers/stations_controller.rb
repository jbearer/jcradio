
# Flag to notify user once queue is almost empty
$notify_laggard_user = true if $notify_laggard_user.nil?

# timing variable
$buddy_last_add = 0 if $buddy_last_add.nil?

require 'yaml'

class StationsController < ApplicationController

    include SongsHelper
    include StationsHelper
    include RecommendationsHelper
    # include Magique

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

    # POST /stations/1/user_spotify_reload_library
    def user_spotify_reload_library
        $spotify_libraries_cached[current_user.username][0] = Time.at(0) # Reset cache timer
        spotify_get_all_songs($client_spotifies[current_user.username]) # Call function to poll all songs again
        redirect_to "/stations/1"
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
        # print "  CurQueuePos: %s\n" % @station.queue_pos

        in_param = Integer(params[:new_queue_pos])
        if in_param <= @station.queue_max and in_param >= 0
            @station.update queue_pos: in_param
        end

        # print "  QueuePos: %s\n" % @station.queue_pos

        redirect_to "/stations/1/change_queue_pos"

    end


    def buddy_add_song

        # if @station.users.order(:position)[0] != User.find_by(username: "Buddy")
        if @station.users.order(:position)[0].username != "Buddy"
            logger.info("****************************")
            logger.info("Not Buddy's turn!")
            logger.info("****************************")
            return
        else
            logger.info("****************************")
            logger.info("Buddy's turn!")
            logger.info("NextLetter = #{$the_next_letter}")
            logger.info("****************************")
        end

        # Only Buddy alone
        if @station.users.length == 1 and @station.queue_max - @station.queue_pos >= 3
            logger.info("****************************")
            logger.info("Buddy is lonely. Buddy will wait for smaller queue")
            logger.info("****************************")
            return
        end

        # Queue long, waiting
        if @station.queue_max - @station.queue_pos > 10
            logger.info("****************************")
            logger.info("Too many songs in the queue. Buddy will wait!")
            logger.info("****************************")
            return
        end

        # Hack to prevent multiple songs added at once
        if Time.now.to_f - $buddy_last_add < 5
            logger.info("************************************************")
            logger.info("Hey Buddy, don't spam the queue. wait some more")
            logger.info("************************************************")
            return
        end
        $buddy_last_add = Time.now.to_f

        ###########################################################################################
        ## Add a song
        # Loop through all tastes checked
        total_songs = []
        $buddy_taste.each do |taste|

            user, source = taste.split("_")
            user = user.capitalize

            logger.info("****************************")
            logger.info("Buddy Taste: taste")

            if source == "played"
                if user == "Radio"
                    queued = QueueEntry.all.joins(:song).where.not(position: nil)\
                            .where(songs: {first_letter: $the_next_letter})
                else # All other normal users
                    queued = QueueEntry.all.joins(:song).where.not(position: nil).where(selector: User.find_by(username: user))\
                            .where(songs: {first_letter: $the_next_letter})
                end
                songs = queued.map {|q| q.song}
                logger.info("*******************************************************")
                logger.info("Buddy: #{user}'s Played songs len: #{songs.length}")
                logger.info("*******************************************************")

            elsif source == "upvoted"
                if user == "Radio"
                    queued = QueueEntry.all.joins(:upvotes).joins(:song).where.not(position: nil)\
                            .where.not(upvotes: {upvoter_id: nil})\
                            .where(songs: {first_letter: $the_next_letter})
                else # All other users
                    queued = QueueEntry.all.joins(:upvotes).joins(:song).where.not(position: nil)\
                            .where(upvotes: {upvoter_id: User.find_by(username: user).id})\
                            .where(songs: {first_letter: $the_next_letter})
                end
                songs = queued.map {|q| q.song}
                logger.info("*******************************************************")
                logger.info("Buddy: #{user}'s Upvoted songs len: #{songs.length}")
                logger.info("*******************************************************")

            elsif source == "spotify"
                if user == "Radio"
                    songs = []
                    logger.info("Sorry, this isn't implemented yet")
                else # All other normal users
                    client_spotify = $client_spotifies[user]
                    if not client_spotify then
                        songs = []
                        logger.info("Not logged into Spotify")

                    end
                    spotify_songs = spotify_get_all_songs(client_spotify, user)
                    results = SongsHelper.get_or_create_from_spotify_record(spotify_songs, true)
                    songs = []
                    results.each do |s|
                        if $the_next_letter == SongsHelper.first_letter(s.title) then
                            songs.append(s)
                        end
                    end
                end
                logger.info("*******************************************************")
                logger.info("Buddy: #{user} Spotify songs len: #{songs.length}")
                logger.info("*******************************************************")

            else
                logger.info("*******************************************************")
                logger.info(" Sorry, buddy_taste='#{$buddy_taste}'' isn't supported yet. Default to 'radio_played'")
                logger.info("*******************************************************")
                songs = []
            end

            # Append songs to total songs (and filter for unique)
            total_songs.concat(songs).uniq
        end

        logger.info("**********************************")
        logger.info("total_songs.length: #{total_songs.length}")
        logger.info("**********************************")

        # If no song results, default to radio_played
        if total_songs.length == 0
            total_songs = Song.where(first_letter: $the_next_letter).limit(100)
            logger.info("0 songs, so defaulted to radio_played")
            logger.info("**********************************")
        end

        # Get Buddy user
        @buddy = User.find_by(username: "Buddy")

        # Get random number for the song
        chosen_song = total_songs[rand(total_songs.length)]
        err_str = @station.queue_song(chosen_song, @buddy, false)

        if err_str != "" then
            logger.info("\n\n\n\n****************************")
            logger.info("err: #{err_str}")
            logger.info("****************************")
            return
        end

        logger.info("****************************")
        logger.info("Buddy chose... #{chosen_song.title}")
        logger.info("****************************")

        @buddy.update position: @station.users.maximum(:position) + 1

        # Notify the next user that it's their turn to pick a song.
        next_user = @station.users.order(:position)[0]
        $the_next_letter = chosen_song.next_letter.capitalize()[0]

        if next_user != @buddy and @station.users.length > 2
            broadcast :next_up, next_user, $the_next_letter
        end

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

        if next_user != current_user and
                @station.users.length > (1 + (@station.users.include?(User.find_by(username: "Buddy")) ? 1 : 0))
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
        $spotify_user.player.next

        broadcast :push, "#{params[:user]} skipped the song."
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
                logger.info("!!!!!!!! saved song to library !!!!!!!!!!!")
                render json: {success: true, saved: true}
            else
                logger.info("!!!!!!!! user not associated with spotify acct !!!!!!")
            end
        rescue => e
            logger.info("!!!!!!!! failed to save song !!!!!!!!!!!")
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
        logger.error("**************")
        logger.error("refresh_now_playing_and_stuff")
        if !$the_background_thread.nil?
            if $the_background_thread.status == 'sleep'
                $the_background_thread.wakeup
            end
        else
            logger.error("**************")
            logger.error("the_background_thread is nil!!!")
        end

        # Check if it's Buddy's turn
        # ActiveRecord::Base.logger.level = 0
        buddy_add_song
        # ActiveRecord::Base.logger.level = 1

        # call update_timing, in case the song didn't change, but the
        # end time did change
        @station.update_timing_stats

    end

    # GET /stations/1/plots
    def plots

    end

end

