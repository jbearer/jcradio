class SessionsController < ApplicationController
  # GET /sessions
  def index
    Rails.logger.error "Logged in as #{current_user}"
    if logged_in?
        redirect_to "/users/#{current_user.id}"
    else
        redirect_to "/sessions/new"
    end
  end

  def new
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
            @user.update position: (User.maximum(:position) || -1) + 1
            session[:user_id] = @user.id
            Rails.logger.error "Logged in as #{current_user}"
        end
    end

    redirect_to "/sessions"
  end

  # DELETE /sessions
  def destroy
    if logged_in?
        current_user.update position: nil
        reset_session
    else
        error "cannot log out (not logged in)"
    end

    redirect_to "/sessions"
  end
end
