class SessionsController < ApplicationController
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
                raise "position must not be nil" if @user.position.nil?
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
        current_user.update position: nil
        reset_session
    else
        error "cannot log out (not logged in)"
    end

    return_to_page
  end

  # POST /sessions/subscribe
  #   endpoint:string: subscription server endpoint
  #   keys: {
  #     auth:string
  #     p256dh: "string"
  #   }
  def subscribe
    if logged_in?
      # If we already have a session, just associate the subscription with the user.
      current_user.update subscription: JSON.dump(params)
      return json_ok
    else
      # Otherwise, store the subscription in the session, so that if the user logs in later we can
      # associated this subscription with their account.
      session[:subscription] = params
    end
  end
end
