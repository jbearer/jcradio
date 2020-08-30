class UpvotesController < ApplicationController
    # POST /upvotes
    #   selection_id:string - the selection to upvote
    #
    # This is more of a "toggle" method than a "create".
    def create
        if not logged_in?
            return json_error "You must be logged in to upvote"
        end

        entry = QueueEntry.find(params[:selection_id])
        upvote = current_user.given_upvotes.find_by queue_entry: entry
        if upvote then
            upvote.destroy
            render json: { success: true, upvoted: false }
        else
            Upvote.create upvoter: current_user, queue_entry: entry

            # Upvote in the user's spotify library
            begin
                if $client_spotifies.key?(current_user.username) then
                    song_id = entry.song.source_id
                    tracks = RSpotify::Track.find([song_id])

                    user = $client_spotifies[current_user.username]
                    user.save_tracks!(tracks)
                    puts "!!!!!!!! saved song to library !!!!!!!!!!!"
                else
                    puts "!!!!!!!! user not associated with spotify acct !!!!!!"
                end
            rescue => e
                puts "!!!!!!!! failed to save song !!!!!!!!!!!"
                Rails.logger.error e.message
                e.backtrace.each { |line| Rails.logger.error line }
            end

            render json: { success: true, upvoted: true }
        end
    end
end
