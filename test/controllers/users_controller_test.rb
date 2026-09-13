require 'test_helper'

class UsersControllerTest < ActionController::TestCase
  setup do
    @user = users(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:user)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create user" do
    assert_difference('User.count') do
      post :create, username: 'newcomer'
    end

    assert_redirected_to '/sessions'
  end

  test "should not create a duplicate username" do
    assert_no_difference('User.count') do
      post :create, username: @user.username
    end

    assert_redirected_to '/users/new'
  end

  test "should show user" do
    get :show, id: @user
    assert_response :success
  end

  test "should not destroy user when not logged in" do
    assert_no_difference('User.count') do
      delete :destroy, id: @user
    end

    assert_response :redirect
  end

  test "should destroy own user when logged in" do
    session[:user_id] = @user.id

    assert_difference('User.count', -1) do
      delete :destroy, id: @user
    end

    assert_response :redirect
  end
end
