class NotificationsController < ApplicationController
    before_action :set_notification, only: [:destroy]

    def index
        if not logged_in?
            error "log in to view your notifications"
            return redirect_to "/"
        end

        @notifications = current_user.pending_notifications.order :created_at
    end

    def destroy
        @notification.destroy
        redirect_to "/notifications"
    end

    private
        def set_notification
          @notification = Notification.find(params[:id])
        end
end
