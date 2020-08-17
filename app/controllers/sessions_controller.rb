class SessionsController < ApplicationController
  include ActionController::Live

  # GET /sessions
  def index
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
                @user.update station: station,
                             position: (station.users.maximum(:position) || -1) + 1
            else
              if @user.position.nil?
                # If we're already a member of a station, but we're not in line to add
                # songs to that station, join the back of the line.
                @user.update position: (@user.station.users.maximum(:position) || -1) + 1
              end
            end
            session[:user_id] = @user.id

            # See if we have a subscription to push notifications.
            if session[:subscription]
              @user.update subscription: JSON.dump(session[:subscription])
            end
        end
    end

    return_to_page
  end

  # DELETE /sessions
  def destroy
    if logged_in?
        current_user.update station: nil, position: nil
        LiveRPC.close current_user.id
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
