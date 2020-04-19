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
            @user.update position: (User.maximum(:position) || -1) + 1
            session[:user_id] = @user.id
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
end
