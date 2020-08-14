module ApplicationHelper

  def current_class?(test_path)
    return 'active' if request.path.start_with?(test_path)
    ''
  end

  def current_user
    User.find_by(id: session[:user_id])
  end

  def logged_in?
    !current_user.nil?
  end

end
