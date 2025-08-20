# spec/support/auth_helper.rb
module AuthHelper
  def sign_in(user)
    post "/es/session", params: { email: user.email, password: "password" }
  end

  def sign_in_user(user = nil)
    user ||= create(:user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    user
  end

  def sign_out
    delete "/es/session"
  end

  def sign_in_user_with_locale(user = nil)
    user ||= create(:user)
    # Mock the current_user method to return the user
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    # Mock the authenticate! method to not redirect
    allow_any_instance_of(ApplicationController).to receive(:authenticate!).and_return(true)
    user
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
  config.include AuthHelper, type: :controller
  config.include AuthHelper, type: :view
end
