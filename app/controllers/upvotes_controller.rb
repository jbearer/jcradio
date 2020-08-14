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
            render json: { success: true, upvoted: true }
        end
    end
end
