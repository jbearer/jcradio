class StationsController < ApplicationController

    include SongsHelper

    # GET /stations
    def index
        redirect_to station_path(@station)
    end

    # GET /auth/spotify/callback
    # The first Spotify sign-in becomes the radio account; later ones link a listener's own.
    def spotify_create_user
        account = RSpotify::User.new(request.env['omniauth.auth'])

        if SpotifyAccounts.radio.nil?
            SpotifyAccounts.sign_in_radio(account)
            PlaybackPoller.start
            PlaybackPoller.wake
            redirect_to sessions_path
        elsif current_user
            SpotifyAccounts.link(current_user, account)
            redirect_to station_path(@station)
        else
            json_error "user must be logged in to link account"
        end
    end

    # POST /stations/1/user_spotify_logout
    def user_spotify_logout
        SpotifyAccounts.unlink(current_user)
        redirect_to sessions_path
    end

    # POST /stations/1/user_spotify_reload_library
    def user_spotify_reload_library
        SpotifyAccounts.expire_library(current_user)
        SpotifyAccounts.library(current_user)
        redirect_to station_path(@station)
    end

    # GET /stations/1
    def show
        respond_to do |format|
            format.html { PlaybackPoller.refresh_later(@station) }
            format.json do
                response.headers['Cache-Control'] = 'no-store'
                render json: {
                    queue_html: render_to_string(partial: 'queue', formats: [:html]),
                    next_user: @station.current_selector,
                    next_letter: @station.next_letter
                }
            end
        end
    end

    def change_queue_pos
    end

    # POST /stations/1/edit_queue_pos
    def edit_queue_pos
        new_pos = Integer(params[:new_queue_pos])
        if new_pos <= @station.queue_max and new_pos >= 0
            @station.update queue_pos: new_pos
        end

        redirect_to "/stations/#{@station.id}/change_queue_pos"
    end

    # POST /stations/1
    #   source_id: Spotify track ID
    #   song_next_letter: optional override of the letter handed to the next selector
    # Add the song to the queue.
    def update
        if not logged_in?
            return json_error "must log in to add to the queue"
        end

        station = current_user.station
        if not station
            return json_error "join a station to add to the queue"
        end

        if not station.turn?(current_user)
            return json_error "it's not your turn to add to the queue"
        end

        begin
            song = Song.get "Spotify", params[:source_id]
        rescue RestClient::TooManyRequests
            return json_error "Spotify is rate limiting us right now; wait a minute and try again"
        end

        if not song
            return json_error "couldn't look that song up on Spotify"
        end

        error = station.queue_song(song, current_user, params[:was_recommended])
        if error != "" then
            return json_error error
        end

        station.advance_turn(current_user, params[:song_next_letter].presence || song.next_letter)

        json_ok
    end

    # POST /stations/1/skip_song
    # Skip to the next song on Spotify
    def skip_song
        SpotifyAccounts.radio.player.next

        broadcast :push, "#{params[:user]} skipped the song."
        redirect_to station_path(@station)
    end

    # POST /stations/1/save
    # Save the currently playing song to the listener's own Spotify library.
    def save
        begin
            song = current_user.station.now_playing.song
            account = SpotifyAccounts.linked(current_user)

            if account
                account.save_tracks!(RSpotify::Track.find([song.source_id]))
                SpotifyAccounts.expire_library(current_user)

                push(Notification.create({
                    user: current_user,
                    text: "Added to library: " + song.title
                }))
                return render json: {success: true, saved: true}
            else
                logger.info "#{current_user.username} has no linked Spotify account to save to"
            end
        rescue => e
            logger.error "failed to save song to library: #{e.message}"
            e.backtrace.each { |line| logger.error line }
        end

        render json: {success: true, saved: false}
    end

    # POST /stations/1/refresh
    # Refresh the now_playing window
    def refresh
        @station.refresh_playback

        render json: { success: true }
    end

    # GET /stations/1/plots
    def plots

    end

end

