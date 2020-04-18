class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    if Rails.env.development?
        skip_before_action :verify_authenticity_token
    end

    helper_method :current_user
    def current_user
        User.find_by(id: session[:user_id])
    end

    helper_method :logged_in?
    def logged_in?
        !current_user.nil?
    end

    helper_method :error
    def error(msg)
        flash[:error] = msg
        Rails.logger.error msg
    end

    helper_method :json_ok
    def json_ok
        respond_to do |format|
            format.json { render json: {success: true} }
        end
    end

    helper_method :json_error
    def json_error(msg)
        respond_to do |format|
            error msg
            format.json { render json: {success: false, error: msg} }
            format.html
        end
    end
end
