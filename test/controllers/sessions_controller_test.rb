require 'test_helper'

class SessionsControllerTest < ActionController::TestCase
  setup do
    @user = users(:one)
    @previous_next_letter = $the_next_letter
    # A blank queue cannot supply a next letter, so skip that lookup on login.
    $the_next_letter = 'A'
  end

  teardown do
    $the_next_letter = @previous_next_letter
  end

  test "logging in joins the station and starts a session" do
    post :create, username: @user.username

    assert_response :redirect
    assert_equal @user.id, session[:user_id]
    assert_equal stations(:one), @user.reload.station
    assert_equal 0, @user.position
  end

  test "logging in as an unknown user does not start a session" do
    post :create, username: 'nobody'

    assert_response :redirect
    assert_nil session[:user_id]
    assert_equal "no such user nobody", flash[:error]
  end

  test "logging out leaves the station and clears the session" do
    @user.update station: stations(:one), position: 0
    session[:user_id] = @user.id

    delete :destroy

    assert_response :redirect
    assert_nil session[:user_id]
    assert_nil @user.reload.station
    assert_nil @user.position
  end

  test "logging out when not logged in reports an error" do
    delete :destroy

    assert_response :redirect
    assert_equal "cannot log out (not logged in)", flash[:error]
  end
end
