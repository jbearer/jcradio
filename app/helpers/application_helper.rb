module ApplicationHelper

  def current_class?(test_path)
    return 'active' if request.path.start_with?(test_path)
    ''
  end

end
