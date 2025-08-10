# spec/support/auth_helper.rb
module AuthHelper
  def sign_in(user)
    post "/session", params: { email: user.email, password: "password" }
  end

  def sign_in_user(user = nil)
    user ||= create(:user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    user
  end

  def sign_out
    delete "/session"
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
  config.include AuthHelper, type: :controller
end
