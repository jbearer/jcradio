class UsersController < ApplicationController
  before_action :set_user, only: [:show, :destroy]

  def index
    @user = User.all.order("created_at ASC")
  end

  # GET /users/1
  # GET /users/1.json
  def show
    respond_to do |format|
      format.html
      format.json { render json: @user }
    end
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # POST /users
  #   username: string
  def create
    if User.find_by(username: params[:username])
      error "#{params[:username]} is already taken"
      redirect_to "/users/new"
    else
      User.create(username: params[:username])
      redirect_to "/sessions"
    end
  end

  # DELETE /users/1
  def destroy
    if !logged_in? or current_user.id != @user.id
      return json_error "cannot delete account #{@user.username} (not logged in)"
    end

    reset_session
    @user.delete

    json_ok
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def user_params
      params.require(:user).permit(:username, :position)
    end
end
