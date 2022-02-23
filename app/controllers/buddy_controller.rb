
class BuddyController < ApplicationController

    def index
        $buddy_on = false
        User.where.not(position: nil).each do |user|
            if user.username == "Buddy"
                $buddy_on = true
            end
        end
        @buddy_taste = $buddy_taste
        @buddy_on = $buddy_on

        # Send the array from Ruby side
        @buddy_users = ["Radio", "Aurora", "Austin", "Daniel", "Jeb", "Lilly"]

        # Specify who has linked their spotify
        @spotify_users = $client_spotifies.keys

    end

    # POST /buddy/configure
    def configure
        buddy_on = params[:buddy_on] == "true"
        $buddy_taste = params[:buddy_taste]

        # Check if just turned on
        if buddy_on && !$buddy_on
            buddy_join
        elsif !buddy_on && $buddy_on
            buddy_logout
        end
        $buddy_on = buddy_on

        # Debug printing
        puts "\n\n**********************"
        puts "buddy_taste:"
        puts $buddy_taste.inspect
        puts "**********************\n\n"

        redirect_to "/buddy"
    end

    # POST /sessions/buddy_join
    def buddy_join
        puts "*******************************"
        puts "Buddy Joined!!!"
        puts "*******************************"

        @user = User.find_by(username: "Buddy")
        @station = Station.find 1

        # Push back all other users
        User.where("position > ?", @station.users.minimum(:position) || -1).each do |inc_user|
            inc_user.update position: inc_user.position + 1
        end
        @user.update station: @station,
                     position: (@station.users.minimum(:position) || -1) + 1

        broadcast :push, "#{@user.username} joined the radio."

    end

    def buddy_logout
        puts "*******************************"
        puts "Buddy Left :("
        puts "*******************************"

        # Push back all other users
        @user = User.find_by(username: "Buddy")
        User.where("position > ?", @user.position).each do |inc_user|
            inc_user.update position: inc_user.position-1
        end

        @user.update station: nil, position: nil

        broadcast :push, "#{@user.username} left the radio." # Send a notification to everyone else
    end




end
