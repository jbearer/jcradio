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
            format.html { return_to_page }
        end
    end

    helper_method :json_error
    def json_error(msg)
        respond_to do |format|
            error msg
            format.json { render json: {success: false, error: msg} }
            format.html { return_to_page }
        end
    end

    # Return to the page that the user was on when they submitted a form.
    helper_method :return_to_page
    def return_to_page
        redirect_to (params[:redirect] || request.original_url)
    end

    helper_method :vapid_key
    def vapid_key
        vapid = Vapid.find(1)
        {
            public_key: vapid.public_key,
            private_key: vapid.private_key,
        }
    end

    helper_method :push
    def push(text, user=current_user)
        if user
            subscription = JSON.parse(user.subscription)
        elsif session[:subscription]
            subscription = session[:subscription]
        else
            return
        end

        Webpush.payload_send({
            message: text,
            endpoint: subscription["endpoint"],
            p256dh: subscription["keys"]["p256dh"],
            auth: subscription["keys"]["auth"],
            vapid: vapid_key
        })
    end
end
