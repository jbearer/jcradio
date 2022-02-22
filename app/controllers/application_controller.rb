require "live-rpc"

# # Global Variables, b/c ruby is confusing
# $client_spotifies = {} # Moved location, for loading on home page
# $the_next_letter = '_'
# $spotify_libraries_cached = {} # Cache spotify library for each user (logging time too, for expiry)
# $spotify_user = nil

# $station = nil

# Disable SQL logging
ActiveRecord::Base.logger.level = 1

class ApplicationController < ActionController::Base
    include ApplicationHelper

    # puts "\n\n\n\n********************$$$$$$$$$$$$$**************@@@@@@@@@@@@@***********"
    # puts " Global defined again..."
    # puts "********************$$$$$$$$$$$$$**************@@@@@@@@@@@@@***********\n\n\n\n"
    # puts "\n*"*10

    # Global Variables, b/c ruby is confusing
    if $client_spotifies.nil?
        $client_spotifies = {} # Moved location, for loading on home page
    end
    if $the_next_letter.nil?
        $the_next_letter = '_'
    end
    if $spotify_libraries_cached.nil?
        $spotify_libraries_cached = {} # Cache spotify library for each user (logging time too, for expiry)
    end

    # $spotify_user = nil
    # $station = nil

    before_action :set_station
    def set_station
        @station = Station.find 1
    end

    EMOJI_REGEX = /:[A-Za-z_-]+:/

    protect_from_forgery with: :exception
    if Rails.env.development?
        skip_before_action :verify_authenticity_token
    end

    before_action :set_current_user
    def set_current_user
        cookies[:current_user] = JSON.dump(current_user.to_h)
    end

    def error(msg)
        flash[:error] = msg
        Rails.logger.error msg
    end

    def json_ok
        respond_to do |format|
            format.json { render json: {success: true} }
            format.html { return_to_page }
        end
    end

    def json_error(msg)
        respond_to do |format|
            error msg
            format.json { render json: {success: false, error: msg} }
            format.html { return_to_page }
        end
    end

    # Return to the page that the user was on when they submitted a form.
    def return_to_page
        redirect_to (params[:redirect] || request.original_url)
    end

    # Declare a client-side function to be callable from the server.
    #
    # Usage:
    #   class MyController < ApplicationController
    #       client_function :my_javascript_function
    #
    #       ...
    #
    #       def some_endpoint
    #           my_javascript_function arg1, arg2, ...
    #       end
    #   end
    #
    # Calling a function declared with client_function will cause the function
    # of the same name to be called in the currently logged-in user's browser.
    # To call a client_function in a different user's session, use `notify` or
    # `broadcast`.
    #
    # Note that the call is fire-and-forget: the server-side function call will
    # return as soon as the message is sent to the client, even if the client-
    # side JavaScript function runs for some time. There is no way to get the
    # return value of the JavaScript function. This is a limitation of the
    # current implementation only; synchronous client-side calls can be added if
    # needed.
    def self.client_function(*functions)
        functions.each do |function|
            define_method function do |*args|
                if subscribed?
                    LiveRPC.call current_user.id, function, args
                end
            end
        end
    end

    # Call a client-side function in the given user's session.
    #
    # Usage: notify user, :my_javascript_function, arg1, arg2, ...
    #
    # This is like calling my_javascript_function(arg1, arg2, ...) in user's
    # browser.
    def notify(user, function, *args)
        LiveRPC.call user.id, function, args
    end

    def push(notification)
        LiveRPC.call notification.user.id, :push,
            [notification.text, "/notifications/#{notification.id}"]
    end

    # Call a client-side function in every active user's session.
    #
    # Usage: broadcast :my_javascript_function, arg1, arg2, ...
    #
    # This is like calling my_javascript_function(arg1, arg2, ...) in the
    # browser of every currently logged-in user.
    def broadcast(function, *args)
        LiveRPC.broadcast function, args
    end

    # Check if the current session has a subscription to LiveRPC calls.
    helper_method :subscribed?
    def subscribed?
        logged_in? and LiveRPC.server? current_user.id
    end

    # JavaScript function to refresh the page.
    client_function :refresh
end
