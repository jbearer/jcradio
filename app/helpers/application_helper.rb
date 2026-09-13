module ApplicationHelper

  def current_class?(test_path)
    return 'active' if request.path.start_with?(test_path)
    ''
  end

  # Memoized per request (nil too); the controller's copy is handed to the view via view_assigns.
  def current_user
    return @current_user if defined?(@current_user)
    @current_user = User.find_by(id: session[:user_id])
  end

  def logged_in?
    !current_user.nil?
  end

end
