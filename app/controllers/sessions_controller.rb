require 'yaml'


class SessionsController < ApplicationController
  include ActionController::Live
  include StationsHelper
  # include Magique

  # GET /sessions
  def index
    # Auto-login to spotify if possible
    if not $spotify_user
      file_path = File.join(Dir.home, "/jcradio/.nothingtoseehere.yml")
      if File.exist?(file_path)
        $spotify_user = RSpotify::User.new(YAML.load_file(file_path))
        # Update the song that's currently playing
        TitleExtractorWorker.perform_async(@station)
      end
    end
  end

  # POST /sessions/radio_spotify_logout
  def radio_spotify_logout
    $spotify_user = nil
    redirect_to "/sessions"
  end

  # POST /sessions
  #     username: string
  def create
    if logged_in?
        error "cannot log in (already logged in as #{current_user.username}"
    else
        @user = User.find_by(username: params[:username])
        if not @user
            error "no such user #{params[:username]}"
        else
            if @user.station.nil?
                station = Station.find 1

                # Push back all other users
                User.where("position > ?", station.users.minimum(:position) || -1).each do |inc_user|
                  puts "\n\n\n&&&&&&&"
                  puts inc_user.username, inc_user.position
                  inc_user.update position: inc_user.position + 1
                  puts inc_user.username, inc_user.position
                  puts "\n\n\n&&&&&&&"
                end

                @user.update station: station,
                             position: (station.users.minimum(:position) || -1) + 1
                puts "\n\n\n&&&&&&&"
                puts @user.username, @user.position
            else
              if @user.position.nil?
                # Push back all other users
                User.where("position > ?", @user.station.users.minimum(:position) || -1).each do |inc_user|
                  puts "\n\n\n&&&&&&&"
                  puts inc_user.username, inc_user.position
                  inc_user.update position:  inc_user.position + 1
                  puts inc_user.username, inc_user.position
                  puts "\n\n\n&&&&&&&"
                end
                # If we're already a member of a station, but we're not in line to add
                # songs to that station, join the back of the line.
                @user.update position: (@user.station.users.minimum(:position) || -1) + 1
                puts "\n\n\n&&&&&&&"
                puts @user.username, @user.position
              end
            end
            session[:user_id] = @user.id

            # See if we have a subscription to push notifications.
            if session[:subscription]
              @user.update subscription: JSON.dump(session[:subscription])
            end
        end
        broadcast :push, "#{current_user.username} joined the radio."

        # Set the next_letter properly, if currently unset
        if @station and $the_next_letter == "_" or $the_next_letter == ""
          $the_next_letter = @user.station.queue[@user.station.queue_max - @user.station.queue_pos].song.next_letter
        end

    end

    return_to_page
  end

  # DELETE /sessions
  def destroy
    if logged_in?
        # If spotify linked, reset spotify library cache time
        if $client_spotifies.key?(current_user.username)
          $spotify_libraries_cached[current_user.username][0] = Time.at(0) # Reset cache
        end

        # Push back all other users
        User.where("position > ?", current_user.position).each do |inc_user|
          puts "\n\n\n&&&&&&&"
          puts inc_user.username, inc_user.position
          inc_user.update position: inc_user.position-1
          puts inc_user.username, inc_user.position
          puts "\n\n\n&&&&&&&"
        end

        current_user.update station: nil, position: nil
        LiveRPC.close current_user.id

        broadcast :push, "#{current_user.username} left the radio." # Send a notification to everyone else

        reset_session
    else
        error "cannot log out (not logged in)"
    end

    return_to_page
  end

  # GET /sessions/subscribe
  def subscribe
    if logged_in?
      response.headers['Content-Type'] = 'text/event-stream'
      LiveRPC.serve current_user.id, response.stream
    else
      json_error "must be logged in to subscribe to events"
    end
  end

  if Rails.env.development?
    client_function :notifyme

    # POST /sessions/notifyme
    #   text:string
    #
    # This endpoint is just for developers to check if notifications are working correctly.
    def test_notifications
      notifyme params[:text]
      json_ok
    end
  end
end
